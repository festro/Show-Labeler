#!/usr/bin/env python3
"""
Fetch_Metadata.py - one-time metadata fetcher for the Video Webplayer.

Fills  Series/.metadata/  with:
    titles.txt            episode names
    posters/<Arc>.jpg     one poster per arc
and converts any  subs/*.srt  to  subs/*.vtt.
Afterwards, run Generate_Menu.bat to rebuild index.html.

FIRST RUN creates  Series/.metadata/metadata.ini  - fill it in and run again.
Your API key lives only in that local file.

Providers (set 'provider' in metadata.ini):
    omdb  - IMDb data via omdbapi.com. One series poster, reused per arc.
            Free key: https://www.omdbapi.com/apikey.aspx
    tmdb  - themoviedb.org. Distinct per-season posters + episode names.
            Free key: https://www.themoviedb.org/settings/api  (v3 API Key)

Stdlib only (no pip installs). Episode numbering matches the generator:
arcs in name order, files in name order; the Nth file of an arc pairs with
episode N of that arc's mapped season.
"""

import os
import re
import ssl
import sys
import json
import shutil
import tempfile
import urllib.parse
import urllib.request

VIDEO_EXT = {'.mp4', '.webm', '.mov', '.m4v', '.mkv', '.avi'}
TMDB_IMG = 'https://image.tmdb.org/t/p/w500'


# ---------- filesystem enumeration (mirrors the generator) ----------

def list_arcs(series_dir):
    names = [d for d in os.listdir(series_dir)
             if os.path.isdir(os.path.join(series_dir, d)) and not d.startswith('.')]
    return sorted(names, key=str.lower)


def list_videos(arc_dir):
    names = [f for f in os.listdir(arc_dir)
             if os.path.isfile(os.path.join(arc_dir, f))
             and os.path.splitext(f)[1].lower() in VIDEO_EXT]
    return sorted(names, key=str.lower)


# ---------- config ----------

def scaffold_ini(path, arc_names):
    lines = [
        '# metadata.ini  -  settings for Fetch_Metadata.py',
        '',
        '# provider = omdb  (IMDb data)  |  tmdb  (distinct per-season posters)',
        'provider = omdb',
        '',
        '# API key for the chosen provider:',
        '#   OMDb: https://www.omdbapi.com/apikey.aspx',
        '#   TMDB: https://www.themoviedb.org/settings/api   (the v3 "API Key")',
        'apikey = YOUR_API_KEY_HERE',
        '',
        "# Series IMDb id (the tt....... code in the show's IMDb URL) - works for both:",
        'imdb = tt0000000',
        '',
        '# (optional) TMDB numeric TV id, if you would rather not resolve via IMDb:',
        '# tmdb =',
        '',
        '# Map each arc folder to a season number.',
        '# Arcs sharing a season are numbered continuously: if the show is ONE',
        '# season split across two arc folders, map BOTH to the same season and',
        '# the second arc continues after the first (e.g. eps 1-34 then 35-67).',
        "# Force a start with 'season:startEpisode', e.g.  Guardian Force = 1:35",
    ]
    lines += ['{0} = {1}'.format(a, i) for i, a in enumerate(arc_names, start=1)]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def parse_ini(path):
    cfg = {'provider': 'omdb', 'apikey': None, 'imdb': None, 'tmdb': None, 'seasons': {}}
    with open(path, encoding='utf-8-sig') as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue
            k, v = line.split('=', 1)
            k, v = k.strip(), v.strip()
            kl = k.lower()
            if kl == 'provider':
                cfg['provider'] = v.lower()
            elif kl == 'apikey':
                cfg['apikey'] = v
            elif kl == 'imdb':
                cfg['imdb'] = v
            elif kl == 'tmdb':
                cfg['tmdb'] = v
            else:
                cfg['seasons'][kl] = v
    return cfg


# ---------- subtitles ----------

def srt_to_vtt(text):
    text = re.sub(r'(\d\d:\d\d:\d\d),(\d{3})', r'\1.\2', text)
    return 'WEBVTT\n\n' + text


def convert_subs(subs_dir):
    if not os.path.isdir(subs_dir):
        return
    for name in os.listdir(subs_dir):
        if not name.lower().endswith('.srt'):
            continue
        srt = os.path.join(subs_dir, name)
        vtt = os.path.splitext(srt)[0] + '.vtt'
        if os.path.exists(vtt):
            continue
        raw = None
        for enc in ('utf-8-sig', 'cp1252', 'latin-1'):
            try:
                with open(srt, encoding=enc) as f:
                    raw = f.read()
                break
            except UnicodeDecodeError:
                continue
        if raw is None:
            print('  [warn] could not decode {0}'.format(name))
            continue
        with open(vtt, 'w', encoding='utf-8', newline='\n') as f:
            f.write(srt_to_vtt(raw))
        print('  converted {0} -> {1}'.format(name, os.path.basename(vtt)))


# ---------- http (stdlib, with a TLS fallback for cert-less pythons) ----------

def _open(url):
    try:
        return urllib.request.urlopen(url, timeout=30)
    except urllib.error.URLError as e:
        if isinstance(getattr(e, 'reason', None), ssl.SSLError):
            print('  [warn] TLS verification failed; retrying without verification')
            return urllib.request.urlopen(url, timeout=30, context=ssl._create_unverified_context())
        raise


def http_json(url):
    with _open(url) as r:
        return json.loads(r.read().decode('utf-8'))


def http_download(url, dest):
    with _open(url) as r, open(dest, 'wb') as f:
        shutil.copyfileobj(r, f)


# ---------- provider endpoints ----------

def omdb_url(apikey, params):
    p = {'apikey': apikey}
    p.update(params)
    return 'https://www.omdbapi.com/?' + urllib.parse.urlencode(p)


def tmdb_url(path, apikey, extra=None):
    p = {'api_key': apikey}
    if extra:
        p.update(extra)
    return 'https://api.themoviedb.org/3' + path + '?' + urllib.parse.urlencode(p)


def tmdb_tv_id(cfg, fetch):
    if cfg.get('tmdb'):
        return cfg['tmdb']
    imdb = cfg.get('imdb')
    if not imdb:
        return None
    data = fetch(tmdb_url('/find/' + imdb, cfg['apikey'], {'external_source': 'imdb_id'}))
    tv = data.get('tv_results') or []
    return tv[0]['id'] if tv else None


def fetch_season(provider, apikey, series_id, season, fetch):
    """Return (title_by_episode_number, poster_url_or_None) for one season."""
    titles = {}
    if provider == 'tmdb':
        data = fetch(tmdb_url('/tv/{0}/season/{1}'.format(series_id, season), apikey))
        for ep in data.get('episodes', []):
            n, nm = ep.get('episode_number'), ep.get('name')
            if n is not None and nm:
                titles[int(n)] = nm
        pp = data.get('poster_path')
        return titles, (TMDB_IMG + pp if pp else None)
    # omdb
    data = fetch(omdb_url(apikey, {'i': series_id, 'Season': season}))
    if data.get('Response') == 'True':
        for ep in data.get('Episodes', []):
            try:
                titles[int(ep['Episode'])] = ep['Title']
            except (KeyError, ValueError):
                pass
    return titles, None


# ---------- title assembly (fetch injected so it is testable) ----------

def parse_season_spec(spec):
    """'1' -> ('1', None) ; '1:35' -> ('1', 35). The optional start forces the
    absolute episode number the arc begins at."""
    spec = str(spec).strip()
    if ':' in spec:
        s, st = spec.split(':', 1)
        try:
            return s.strip(), int(st.strip())
        except ValueError:
            return s.strip(), None
    return spec, None


def build_titles(series_dir, cfg, fetch=http_json):
    provider = cfg['provider']
    if provider == 'tmdb':
        series_id = tmdb_tv_id(cfg, fetch)
        if not series_id:
            print('  [warn] could not resolve a TMDB id from imdb/tmdb in metadata.ini')
    else:
        series_id = cfg['imdb']

    lines, arc_posters = [], {}
    season_cache = {}   # season -> (title_by_ep, poster_url)
    season_cursor = {}  # season -> next unused absolute episode number
    g = 0
    for arc in list_arcs(series_dir):
        files = list_videos(os.path.join(series_dir, arc))
        if not files:
            continue
        title_by_ep, poster_url, start = {}, None, 1
        spec = cfg['seasons'].get(arc.lower())
        if spec and series_id:
            season, explicit = parse_season_spec(spec)
            if season not in season_cache:
                try:
                    season_cache[season] = fetch_season(provider, cfg['apikey'], series_id, season, fetch)
                except Exception as e:
                    print("  [warn] fetch failed for '{0}' season {1}: {2}".format(arc, season, e))
                    season_cache[season] = ({}, None)
            title_by_ep, poster_url = season_cache[season]
            start = explicit if explicit is not None else season_cursor.get(season, 1)
            named = sum(1 for i in range(len(files)) if title_by_ep.get(start + i))
            print("  arc '{0}': season {1}, eps {2}-{3}, {4}/{5} named".format(
                arc, season, start, start + len(files) - 1, named, len(files)))
            season_cursor[season] = start + len(files)
        else:
            print("  [warn] no season mapping for arc '{0}' - skipping its titles".format(arc))
        arc_posters[arc] = poster_url
        for idx, _f in enumerate(files, start=1):
            g += 1
            t = title_by_ep.get(start + idx - 1)
            if t:
                lines.append('{0}={1}'.format(g, t))
    return lines, arc_posters


def write_titles(path, lines):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + ('\n' if lines else ''))


# ---------- posters ----------

def resolve_posters(cfg, series_dir, arc_posters):
    """Return {arc: poster_url}. TMDB gives per-season urls; OMDb falls back to
    the single series poster applied to every arc."""
    posters = {a: u for a, u in arc_posters.items() if u}
    if posters or cfg['provider'] != 'omdb':
        return posters
    try:
        meta = http_json(omdb_url(cfg['apikey'], {'i': cfg['imdb']}))
        p = meta.get('Poster')
        if p and p != 'N/A':
            return {a: p for a in list_arcs(series_dir)}
    except Exception as e:
        print('[warn] OMDb poster lookup failed: {0}'.format(e))
    return {}


# ---------- main ----------

def main():
    root = os.path.dirname(os.path.abspath(__file__))
    series_dir = os.path.join(root, 'Series')
    meta_dir = os.path.join(series_dir, '.metadata')
    posters_dir = os.path.join(meta_dir, 'posters')
    subs_dir = os.path.join(meta_dir, 'subs')
    ini_path = os.path.join(meta_dir, 'metadata.ini')
    titles_path = os.path.join(meta_dir, 'titles.txt')

    if not os.path.isdir(series_dir):
        sys.exit("No 'Series' folder next to this script: " + series_dir)
    for d in (meta_dir, posters_dir, subs_dir):
        os.makedirs(d, exist_ok=True)

    if not os.path.exists(ini_path):
        scaffold_ini(ini_path, list_arcs(series_dir))
        print('Created ' + ini_path)
        print('Choose a provider, paste its API key + the season numbers, then run again.')
        return

    cfg = parse_ini(ini_path)
    if cfg['provider'] not in ('omdb', 'tmdb'):
        sys.exit("provider must be 'omdb' or 'tmdb' in " + ini_path)
    if not cfg['apikey'] or cfg['apikey'] == 'YOUR_API_KEY_HERE':
        sys.exit('Set your apikey in ' + ini_path)
    if not cfg.get('tmdb') and (not cfg['imdb'] or cfg['imdb'] == 'tt0000000'):
        sys.exit('Set the series imdb id (or a tmdb id) in ' + ini_path)

    print("Provider: {0}".format(cfg['provider']))
    lines, arc_posters = build_titles(series_dir, cfg)
    if lines:
        write_titles(titles_path, lines)
        print('Wrote {0} episode titles to {1}'.format(len(lines), titles_path))
    else:
        print('[warn] No titles fetched - leaving any existing titles.txt untouched.')

    posters = resolve_posters(cfg, series_dir, arc_posters)
    for arc, url in posters.items():
        try:
            dest = os.path.join(posters_dir, arc + '.jpg')
            http_download(url, dest)
            print('  poster: {0}.jpg'.format(arc))
        except Exception as e:
            print("  [warn] poster download failed for '{0}': {1}".format(arc, e))

    convert_subs(subs_dir)
    print('\nDone. Now run Generate_Menu.bat to rebuild index.html.')


if __name__ == '__main__':
    main()
