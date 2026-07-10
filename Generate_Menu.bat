@echo off
chcp 65001 >nul
setlocal DisableDelayedExpansion

REM ============================================================
REM  Generate_Menu.bat
REM  Scans %SERIES_DIR%\<Arc>\*.{mp4,webm,mov,m4v,mkv,avi} and
REM  builds a self-contained video web player (%OUTPUT_FILE%):
REM  continuous playback, resume / last-watched memory, search,
REM  keyboard shortcuts, and optional titles / posters read from
REM  a hidden Series\.metadata folder (skipped by the scan).
REM  Each sub-folder of Series = an "arc"; each video = episode.
REM ============================================================

set "OUTPUT_FILE=index.html"
set "SERIES_DIR=Series"
set "ARCHIVE_TITLE=Media Archive"
set "VIDEO_EXT=.mp4 .webm .mov .m4v .mkv .avi"

REM ---- 1. Static <head> + CSS + top of <body> --------------------------
REM      (delayed expansion OFF so <!DOCTYPE and % survive verbatim)
(
echo ^<!DOCTYPE html^>
echo ^<html lang="en"^>
echo ^<head^>
echo     ^<meta charset="UTF-8"^>
echo     ^<meta name="viewport" content="width=device-width, initial-scale=1.0"^>
echo     ^<title^>%ARCHIVE_TITLE%^</title^>
echo     ^<style^>
echo         body {
echo             background: #0d0d0d url^('backdrop.jpg'^) no-repeat center center fixed;
echo             background-size: cover;
echo             color: #ffffff;
echo             font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Arial, sans-serif;
echo             margin: 0;
echo             padding: 30px;
echo         }
echo         h1 {
echo             text-align: center;
echo             font-size: 2.5rem;
echo             margin-bottom: 25px;
echo             text-transform: uppercase;
echo             letter-spacing: 2px;
echo             text-shadow: 0 4px 10px rgba^(0,0,0,0.9^), 0 0 15px rgba^(0,123,255,0.4^);
echo         }
echo         .main-container {
echo             display: flex;
echo             gap: 30px;
echo             max-width: 1820px;
echo             margin: 0 auto;
echo             align-items: flex-start;
echo         }
echo         .nav-panel {
echo             flex: 1;
echo             max-height: 82vh;
echo             overflow-y: auto;
echo             background: rgba^(15, 15, 15, 0.9^);
echo             border: 1px solid #2d2d2d;
echo             border-radius: 8px;
echo             padding: 20px;
echo             box-shadow: 0 10px 30px rgba^(0,0,0,0.5^);
echo             backdrop-filter: blur^(5px^);
echo         }
echo         .nav-panel::-webkit-scrollbar { width: 6px; }
echo         .nav-panel::-webkit-scrollbar-track { background: rgba^(0,0,0,0.1^); }
echo         .nav-panel::-webkit-scrollbar-thumb { background: #333; border-radius: 4px; }
echo         .nav-panel::-webkit-scrollbar-thumb:hover { background: #007BFF; }
echo         .search-box {
echo             width: 100%%;
echo             box-sizing: border-box;
echo             padding: 10px 12px;
echo             margin-bottom: 15px;
echo             background: rgba^(0,0,0,0.4^);
echo             border: 1px solid #444;
echo             border-radius: 6px;
echo             color: #fff;
echo             font-size: 1rem;
echo             outline: none;
echo         }
echo         .search-box:focus {
echo             border-color: #00c6ff;
echo             box-shadow: 0 0 8px rgba^(0,198,255,0.4^);
echo         }
echo         .search-box::placeholder { color: #888; }
echo         .dvd-controls {
echo             display: flex;
echo             flex-direction: column;
echo             gap: 10px;
echo             margin-bottom: 20px;
echo             background: rgba^(0, 0, 0, 0.4^);
echo             padding: 15px;
echo             border-radius: 6px;
echo             border: 1px dashed #444;
echo         }
echo         .control-btn {
echo             background: #007BFF;
echo             border: 1px solid #00c6ff;
echo             border-radius: 4px;
echo             padding: 12px;
echo             color: white;
echo             font-weight: bold;
echo             font-size: 1.1rem;
echo             text-transform: uppercase;
echo             letter-spacing: 1px;
echo             cursor: pointer;
echo             transition: all 0.2s ease;
echo             text-align: center;
echo         }
echo         .control-btn:hover {
echo             background: #0056b3;
echo             box-shadow: 0 0 12px rgba^(0,198,255,0.6^);
echo             transform: translateY^(-1px^);
echo         }
echo         .control-btn.chapter-btn {
echo             background: #6f42c1;
echo             border-color: #a92fd8;
echo         }
echo         .control-btn.chapter-btn:hover {
echo             background: #563d7c;
echo             box-shadow: 0 0 12px rgba^(169,47,216,0.6^);
echo         }
echo         .control-btn.resume-btn {
echo             background: #ff9800;
echo             border-color: #ffb74d;
echo         }
echo         .control-btn.resume-btn:hover {
echo             background: #f57c00;
echo             box-shadow: 0 0 12px rgba^(255,152,0,0.6^);
echo         }
echo         .arc-section { margin-bottom: 5px; }
echo         .arc-poster {
echo             width: 100%%;
echo             max-height: 220px;
echo             object-fit: cover;
echo             border-radius: 6px;
echo             margin: 15px 0 5px 0;
echo             display: block;
echo         }
echo         .section-title {
echo             font-size: 1.3rem;
echo             color: #00c6ff;
echo             border-bottom: 2px solid #007BFF;
echo             padding-bottom: 5px;
echo             margin: 20px 0 12px 0;
echo             text-transform: uppercase;
echo             font-weight: bold;
echo             letter-spacing: 1px;
echo         }
echo         .episode-grid {
echo             display: grid;
echo             grid-template-columns: repeat^(auto-fill, minmax^(75px, 1fr^)^);
echo             gap: 10px;
echo         }
echo         .episode-card {
echo             background: rgba^(40, 40, 40, 0.6^);
echo             border: 1px solid #444;
echo             border-radius: 4px;
echo             padding: 12px 5px;
echo             color: #fff;
echo             text-decoration: none;
echo             font-weight: 600;
echo             font-size: 0.95rem;
echo             text-align: center;
echo             transition: all 0.15s ease-in-out;
echo             user-select: none;
echo         }
echo         .episode-card:hover {
echo             background: #007BFF;
echo             border-color: #00c6ff;
echo             transform: scale^(1.05^);
echo             cursor: pointer;
echo             box-shadow: 0 0 10px rgba^(0,198,255,0.5^);
echo         }
echo         .episode-card.active {
echo             background: #28a745;
echo             border-color: #28a745;
echo             box-shadow: 0 0 10px rgba^(40,167,69,0.5^);
echo         }
echo         .episode-card.last-watched {
echo             border-color: #ff9800;
echo             box-shadow: 0 0 8px rgba^(255,152,0,0.5^);
echo         }
echo         .player-panel {
echo             flex: 1.8;
echo             position: sticky;
echo             top: 30px;
echo             background: #000000;
echo             border: 2px solid #222;
echo             border-radius: 8px;
echo             box-shadow: 0 15px 40px rgba^(0,0,0,0.8^);
echo             aspect-ratio: 16 / 9;
echo             display: flex;
echo             justify-content: center;
echo             align-items: center;
echo         }
echo         video {
echo             width: 100%%;
echo             height: 100%%;
echo             border-radius: 6px;
echo             object-fit: contain;
echo         }
echo         .placeholder {
echo             color: #777;
echo             font-style: italic;
echo             font-size: 1.2rem;
echo             text-align: center;
echo             padding: 20px;
echo             line-height: 1.6;
echo         }
echo     ^</style^>
echo ^</head^>
echo ^<body^>
echo     ^<h1 id="mainHeading"^>%ARCHIVE_TITLE%^</h1^>
echo     ^<div class="main-container"^>
echo         ^<div class="nav-panel"^>
echo             ^<input type="text" id="searchBox" class="search-box" placeholder="Search episodes..." oninput="filterEpisodes()"^>
echo             ^<div class="dvd-controls"^>
echo                 ^<div id="resumeBar" class="control-btn resume-btn" style="display:none;" onclick="resumePlayback()"^>^</div^>
) > "%OUTPUT_FILE%"

REM ---- 2. Enable delayed expansion for the dynamic folder scan ----------
setlocal EnableDelayedExpansion

REM ---- 2a. Scaffold the hidden .metadata folder (skipped by the scan) ---
if not exist "%SERIES_DIR%" mkdir "%SERIES_DIR%"
if not exist "%SERIES_DIR%\.metadata" mkdir "%SERIES_DIR%\.metadata"
if not exist "%SERIES_DIR%\.metadata\subs" mkdir "%SERIES_DIR%\.metadata\subs"
if not exist "%SERIES_DIR%\.metadata\posters" mkdir "%SERIES_DIR%\.metadata\posters"
attrib +h "%SERIES_DIR%\.metadata" >nul 2>&1
if not exist "%SERIES_DIR%\.metadata\README.txt" (
    >"%SERIES_DIR%\.metadata\README.txt" echo This hidden folder holds optional metadata read by Generate_Menu.bat at build time.
    >>"%SERIES_DIR%\.metadata\README.txt" echo   titles.txt  -  lines  N=Episode Title  where N is the episode number
    >>"%SERIES_DIR%\.metadata\README.txt" echo   posters\    -  one image per arc, named  ArcName.jpg  (or .png / .jpeg)
    >>"%SERIES_DIR%\.metadata\README.txt" echo   subs\       -  WebVTT subtitles named  N.vtt  - file:// support varies by browser
    >>"%SERIES_DIR%\.metadata\README.txt" echo Titles may contain punctuation like colons and apostrophes.
)

REM Global "Play Entire Series" button (emoji round-trips under chcp 65001)
echo                 ^<div class="control-btn" onclick="playMasterPlaylist('all')"^>💿 Play Entire Series^</div^>>>"%OUTPUT_FILE%"

REM ---- 3. One arc button per sub-folder of Series (skip .metadata etc) --
for /f "delims=" %%D in ('dir /b /ad /o:n "%SERIES_DIR%" 2^>nul ^| findstr /v /b /r "[.]"') do (
    set "FOLDER=%%D"
    set "CLEAN_ID=!FOLDER: =_!"
    echo                 ^<div class="control-btn chapter-btn" onclick="playMasterPlaylist('!CLEAN_ID!')"^>🎬 Play !FOLDER! Arc^</div^>>>"%OUTPUT_FILE%"
)
echo             ^</div^>>>"%OUTPUT_FILE%"

REM ---- 4. Episode grids (wrapped in .arc-section) + JS playlist/chapters -
set "GLOBAL_TRACK_COUNT=0"
type nul > "playlist.tmp"
type nul > "chapters.tmp"
type nul > "subs.tmp"

for /f "delims=" %%D in ('dir /b /ad /o:n "%SERIES_DIR%" 2^>nul ^| findstr /v /b /r "[.]"') do (
    set "FOLDER=%%D"
    set "CLEAN_ID=!FOLDER: =_!"
    echo             ^<div class="arc-section" data-arc="!CLEAN_ID!"^>>>"%OUTPUT_FILE%"
    set "POSTER="
    if exist "%SERIES_DIR%\.metadata\posters\%%D.jpg"  set "POSTER=%SERIES_DIR%/.metadata/posters/%%D.jpg"
    if not defined POSTER if exist "%SERIES_DIR%\.metadata\posters\%%D.png"  set "POSTER=%SERIES_DIR%/.metadata/posters/%%D.png"
    if not defined POSTER if exist "%SERIES_DIR%\.metadata\posters\%%D.jpeg" set "POSTER=%SERIES_DIR%/.metadata/posters/%%D.jpeg"
    if defined POSTER echo             ^<img class="arc-poster" src="!POSTER!" alt="!FOLDER! poster"^>>>"%OUTPUT_FILE%"
    echo             ^<div class="section-title"^>!FOLDER! Selection^</div^>>>"%OUTPUT_FILE%"
    echo             ^<div class="episode-grid"^>>>"%OUTPUT_FILE%"
    set /a "ARC_START=GLOBAL_TRACK_COUNT+1"
    for /f "delims=" %%F in ('dir /b /a-d /o:n "%SERIES_DIR%\%%D" 2^>nul ^| findstr /i /e "%VIDEO_EXT%"') do (
        set /a "GLOBAL_TRACK_COUNT+=1"
        set "FILE_PATH=%SERIES_DIR%/%%D/%%F"
        set "LABEL=!GLOBAL_TRACK_COUNT!"
        if !GLOBAL_TRACK_COUNT! lss 10 set "LABEL=0!GLOBAL_TRACK_COUNT!"
        echo                 ^<a class="episode-card" id="epCard-!GLOBAL_TRACK_COUNT!" onclick="playSingleEpisode(!GLOBAL_TRACK_COUNT!)"^>E!LABEL!^</a^>>>"%OUTPUT_FILE%"
        echo         episodePlaylist[!GLOBAL_TRACK_COUNT!] = '!FILE_PATH!';>>"playlist.tmp"
        if exist "%SERIES_DIR%\.metadata\subs\!GLOBAL_TRACK_COUNT!.vtt" echo         episodeSubs[!GLOBAL_TRACK_COUNT!] = '%SERIES_DIR%/.metadata/subs/!GLOBAL_TRACK_COUNT!.vtt';>>"subs.tmp"
    )
    echo             ^</div^>>>"%OUTPUT_FILE%"
    echo             ^</div^>>>"%OUTPUT_FILE%"
    if !GLOBAL_TRACK_COUNT! geq !ARC_START! echo         chapterMap['!CLEAN_ID!'] = [!ARC_START!, !GLOBAL_TRACK_COUNT!];>>"chapters.tmp"
)

REM ---- 4a. Optional episode titles from .metadata\titles.txt ------------
type nul > "titles.tmp"
if exist "%SERIES_DIR%\.metadata\titles.txt" (
    for /f "usebackq tokens=1* delims==" %%a in ("%SERIES_DIR%\.metadata\titles.txt") do (
        set "TNUM=%%a"
        set "TTXT=%%b"
        if defined TTXT (
            set "TTXT=!TTXT:\=/!"
            set "TTXT=!TTXT:'=\'!"
            echo         episodeTitles[!TNUM!] = '!TTXT!';>>"titles.tmp"
        )
    )
)

REM ---- 5. Player shell + open <script> + inject playlist/chapters/titles-
(
echo         ^</div^>
echo         ^<div class="player-panel"^>
echo             ^<div id="fallbackPrompt" class="placeholder"^>
echo                 Select a DVD option or an individual episode from the grid to begin.^<br^>
echo                 ^<small style="color:#555; font-size:0.85rem;"^>Keys: Space play/pause, Left/Right seek 10s, N/P next/prev, F fullscreen, Esc menu^</small^>
echo             ^</div^>
echo             ^<video id="nativeViewer" controls style="display:none;"^>^</video^>
echo         ^</div^>
echo     ^</div^>
echo     ^<script^>
echo         const totalEpisodes = !GLOBAL_TRACK_COUNT!;
echo         const seekStep = 10;
echo         const episodePlaylist = {};
) >> "%OUTPUT_FILE%"

type "playlist.tmp" >> "%OUTPUT_FILE%"
echo         const chapterMap = {};>>"%OUTPUT_FILE%"
type "chapters.tmp" >> "%OUTPUT_FILE%"
echo         const episodeTitles = {};>>"%OUTPUT_FILE%"
type "titles.tmp" >> "%OUTPUT_FILE%"
echo         const episodeSubs = {};>>"%OUTPUT_FILE%"
type "subs.tmp" >> "%OUTPUT_FILE%"

REM ---- 6. Player engine (delayed expansion OFF so JS "!" survives) ------
setlocal DisableDelayedExpansion
(
echo.
echo         let currentQueue = [];
echo         let currentQueueIndex = 0;
echo         let currentEpisode = null;
echo         let pendingSeek = null;
echo         let lastSaveTs = 0;
echo.
echo         const player = document.getElementById^('nativeViewer'^);
echo         const prompt = document.getElementById^('fallbackPrompt'^);
echo         const heading = document.getElementById^('mainHeading'^);
echo         const resumeBar = document.getElementById^('resumeBar'^);
echo         const searchBox = document.getElementById^('searchBox'^);
echo         const archiveTitle = heading.innerText;
echo         const storageKey = 'webplayer:' + archiveTitle;
echo.
echo         function epLabel^(n^) {
echo             const p = n ^< 10 ? '0' + n : n;
echo             return 'E' + p;
echo         }
echo         function epHeading^(n^) {
echo             if ^(episodeTitles[n]^) return epLabel^(n^) + '  —  ' + episodeTitles[n];
echo             return epLabel^(n^);
echo         }
echo.
echo         function readProgress^(^) {
echo             try { return JSON.parse^(localStorage.getItem^(storageKey^)^); }
echo             catch ^(e^) { return null; }
echo         }
echo         function saveProgress^(^) {
echo             if ^(currentEpisode === null^) return;
echo             try {
echo                 localStorage.setItem^(storageKey, JSON.stringify^({ ep: currentEpisode, time: Math.floor^(player.currentTime^) }^)^);
echo             } catch ^(e^) {}
echo         }
echo         function formatTime^(t^) {
echo             t = Math.floor^(t^);
echo             const m = Math.floor^(t / 60^);
echo             const s = t - m * 60;
echo             return m + ':' + ^(s ^< 10 ? '0' + s : s^);
echo         }
echo         function refreshResumeBar^(^) {
echo             document.querySelectorAll^('.episode-card'^).forEach^(c =^> c.classList.remove^('last-watched'^)^);
echo             const data = readProgress^(^);
echo             if ^(!data^) { resumeBar.style.display = 'none'; return; }
echo             if ^(!episodePlaylist[data.ep]^) { resumeBar.style.display = 'none'; return; }
echo             const extra = episodeTitles[data.ep] ? '  —  ' + episodeTitles[data.ep] : '';
echo             resumeBar.textContent = '▶ Resume ' + epLabel^(data.ep^) + extra + '    ' + formatTime^(data.time^);
echo             resumeBar.style.display = 'block';
echo             const card = document.getElementById^('epCard-' + data.ep^);
echo             if ^(card^) card.classList.add^('last-watched'^);
echo         }
echo         function resumePlayback^(^) {
echo             const data = readProgress^(^);
echo             if ^(!data^) return;
echo             if ^(!episodePlaylist[data.ep]^) return;
echo             pendingSeek = data.time;
echo             playSingleEpisode^(data.ep^);
echo         }
echo.
echo         function filterEpisodes^(^) {
echo             const q = searchBox.value.toLowerCase^(^).trim^(^);
echo             document.querySelectorAll^('.arc-section'^).forEach^(sec =^> {
echo                 let anyVisible = false;
echo                 sec.querySelectorAll^('.episode-card'^).forEach^(card =^> {
echo                     const n = card.id.replace^('epCard-', ''^);
echo                     let hay = card.textContent.toLowerCase^(^);
echo                     if ^(episodeTitles[n]^) hay = hay + ' ' + episodeTitles[n].toLowerCase^(^);
echo                     let match = false;
echo                     if ^(q === ''^) match = true;
echo                     else if ^(hay.indexOf^(q^) !== -1^) match = true;
echo                     card.style.display = match ? '' : 'none';
echo                     if ^(match^) anyVisible = true;
echo                 }^);
echo                 sec.style.display = anyVisible ? '' : 'none';
echo             }^);
echo         }
echo.
echo         function executePlayback^(episodeNum^) {
echo             prompt.style.display = 'none';
echo             player.style.display = 'block';
echo             currentEpisode = episodeNum;
echo             player.querySelectorAll^('track'^).forEach^(t =^> t.remove^(^)^);
echo             player.src = episodePlaylist[episodeNum];
echo             const subPath = episodeSubs[episodeNum];
echo             if ^(subPath^) {
echo                 const tr = document.createElement^('track'^);
echo                 tr.kind = 'subtitles';
echo                 tr.label = 'Subtitles';
echo                 tr.srclang = 'en';
echo                 tr.src = subPath;
echo                 tr.default = true;
echo                 player.appendChild^(tr^);
echo             }
echo             player.load^(^);
echo             player.play^(^);
echo             heading.innerText = "Playing: " + epHeading^(episodeNum^);
echo             document.querySelectorAll^('.episode-card'^).forEach^(link =^> link.classList.remove^('active'^)^);
echo             const activeCard = document.getElementById^(`epCard-${episodeNum}`^);
echo             if ^(activeCard^) activeCard.classList.add^('active'^);
echo             saveProgress^(^);
echo         }
echo.
echo         function returnToMainMenu^(^) {
echo             player.pause^(^);
echo             player.src = "";
echo             player.style.display = 'none';
echo             prompt.style.display = 'block';
echo             heading.innerText = archiveTitle;
echo             document.querySelectorAll^('.episode-card'^).forEach^(link =^> link.classList.remove^('active'^)^);
echo             currentQueue = [];
echo             currentQueueIndex = 0;
echo             refreshResumeBar^(^);
echo         }
echo.
echo         function playSingleEpisode^(episodeNum^) {
echo             currentQueue = [episodeNum];
echo             currentQueueIndex = 0;
echo             executePlayback^(episodeNum^);
echo         }
echo.
echo         function playMasterPlaylist^(type^) {
echo             currentQueue = [];
echo             currentQueueIndex = 0;
echo             let range;
echo             if ^(type === 'all'^) {
echo                 range = [1, totalEpisodes];
echo             } else if ^(chapterMap[type]^) {
echo                 range = chapterMap[type];
echo             }
echo             if ^(range^) {
echo                 for ^(let i = range[0]; i ^<= range[1]; i++^) currentQueue.push^(i^);
echo             }
echo             if ^(currentQueue.length ^> 0^) executePlayback^(currentQueue[currentQueueIndex]^);
echo         }
echo.
echo         function seekBy^(delta^) {
echo             if ^(!player.duration^) return;
echo             let t = player.currentTime + delta;
echo             if ^(t ^< 0^) t = 0;
echo             if ^(t ^> player.duration^) t = player.duration;
echo             player.currentTime = t;
echo         }
echo         function nextEpisode^(^) {
echo             if ^(currentEpisode === null^) return;
echo             if ^(currentEpisode ^< totalEpisodes^) playSingleEpisode^(currentEpisode + 1^);
echo         }
echo         function prevEpisode^(^) {
echo             if ^(currentEpisode === null^) return;
echo             if ^(currentEpisode ^> 1^) playSingleEpisode^(currentEpisode - 1^);
echo         }
echo         function toggleFullscreen^(^) {
echo             if ^(!document.fullscreenElement^) {
echo                 if ^(player.requestFullscreen^) player.requestFullscreen^(^);
echo                 else if ^(player.webkitRequestFullscreen^) player.webkitRequestFullscreen^(^);
echo             } else {
echo                 if ^(document.exitFullscreen^) document.exitFullscreen^(^);
echo             }
echo         }
echo.
echo         player.addEventListener^('loadedmetadata', function^(^) {
echo             if ^(pendingSeek !== null^) { player.currentTime = pendingSeek; pendingSeek = null; }
echo         }^);
echo         player.addEventListener^('timeupdate', function^(^) {
echo             const now = Date.now^(^);
echo             if ^(now - lastSaveTs ^> 5000^) { lastSaveTs = now; saveProgress^(^); }
echo         }^);
echo         player.addEventListener^('pause', saveProgress^);
echo.
echo         player.onended = function^(^) {
echo             currentQueueIndex++;
echo             if ^(currentQueueIndex ^< currentQueue.length^) {
echo                 executePlayback^(currentQueue[currentQueueIndex]^);
echo             } else {
echo                 returnToMainMenu^(^);
echo             }
echo         };
echo.
echo         document.addEventListener^('keydown', ^(e^) =^> {
echo             if ^(e.target.tagName === 'INPUT'^) return;
echo             const playing = player.style.display !== 'none';
echo             if ^(e.key === 'Escape'^) {
echo                 if ^(!document.fullscreenElement^) returnToMainMenu^(^);
echo                 return;
echo             }
echo             if ^(!playing^) return;
echo             const k = e.key.toLowerCase^(^);
echo             if ^(e.key === ' '^) {
echo                 e.preventDefault^(^);
echo                 if ^(player.paused^) player.play^(^); else player.pause^(^);
echo             } else if ^(e.key === 'ArrowRight'^) {
echo                 e.preventDefault^(^);
echo                 seekBy^(seekStep^);
echo             } else if ^(e.key === 'ArrowLeft'^) {
echo                 e.preventDefault^(^);
echo                 seekBy^(-seekStep^);
echo             } else if ^(k === 'n'^) {
echo                 nextEpisode^(^);
echo             } else if ^(k === 'p'^) {
echo                 prevEpisode^(^);
echo             } else if ^(k === 'f'^) {
echo                 toggleFullscreen^(^);
echo             }
echo         }^);
echo.
echo         Object.keys^(episodeTitles^).forEach^(n =^> {
echo             const c = document.getElementById^('epCard-' + n^);
echo             if ^(c^) c.title = episodeTitles[n];
echo         }^);
echo         refreshResumeBar^(^);
echo     ^</script^>
echo ^</body^>
echo ^</html^>
) >> "%OUTPUT_FILE%"
endlocal

del "playlist.tmp" "chapters.tmp" "titles.tmp" "subs.tmp" 2>nul
echo.
echo Done. !GLOBAL_TRACK_COUNT! episodes written to %OUTPUT_FILE%.
pause
