#SingleInstance
TraySetIcon 'imageres.dll', 126
KeyHistory(0), ListLines(0)

baseDir := A_Desktop 'bandcamp\'
FileExist(baseDir) || DirCreate(baseDir)
SetWorkingDir baseDir

req := ComObject('WinHttp.WinHttpRequest.5.1')
web := ComObject('HTMLFile')
tip(txt, vars*) => (traytip(format(txt, vars*)), sleep(1500))

SetTimer main

main() {
  critical -1
  static releases := [], files := map()

  clipboard := RegExReplace(A_ClipBoard, '\s')
  if isMusic := clipboard ~= '^https://[\w-]+\.bandcamp\.com/music/?$' {
    try req.open('GET', clipboard, 1), req.send(), req.WaitForResponse()
    catch {
      tip '{}`nСтраница дискографии недоступна.', clipboard
      goto end
    }
    html := req.ResponseText
    web.write html
    RegExMatch html, '<meta property="og:url" +content="(.+)">', &m
    domain := IsObject(m) ? m.1 : ''
    if !domain {
      tip '{}`nНеверная страница исполнителя.', clipboard
      goto end
    }
    loop (links := web.links, len := links.length) {
      link := links[--len].href
      RegExMatch link, '^(.+)?(/(album|track)/.+)$', &m
      if IsObject(m)
        releases.push (InStr(m.1, 'https://') ? m.1 : domain) m.2
    }
  }

  if !releases.length {
    if !(clipboard ~= '^https://[\w-]+\.bandcamp\.com/(album|track)/[\w-]+(\?.+)?$')
      return
    releases.push clipboard
  }

  if isMusic {
    musicPage := StrSplit(web.title, ' | ')[-1]
    tip '{} (релизы: {})`nЗагрузка дискографии …', musicPage, releases.length
  }

  for i in releases {
    isAlbum := InStr(i, '/album/')
    try req.open('GET', i, 1), req.send(), req.WaitForResponse()
    catch {
      tip '{}`nСтраница {} недоступна.', i, isAlbum ? 'альбома' : 'трека'
      continue
    }

    html := req.ResponseText
    RegExMatch html, '<meta property="og:site_name" +content="(.+)">', &m
    artist := IsObject(m) ? filter(m.1) : ''
    if !artist {
      tip '{}`nНеверная страница релиза.', i
      continue
    }
    FileExist(artist) || DirCreate(artist)
    RegExMatch html, '<title>(.+?) \| .+</title>', &m
    release := IsObject(m) ? filter(m.1) : ''
    RegExMatch html, '<meta name="description" +content="[\s\S]+?release. \d+ \w+ (\d{4})', &m
    year := IsObject(m) ? m.1 : ''
    RegExMatch html, '<meta property="og:image" +content="(.+)">', &m
    cover := IsObject(m) ? m.1 : ''
    RegExMatch html, '<meta property="og:description" +content="(\d+) track album">', &m
    amount := IsObject(m) ? m.1 : 0

    pos := 1, files.clear()
    path := artist '\' (isAlbum ? year ' - ' release '\' : '')
    (isAlbum && FileExist(path)) || DirCreate(path)
    (isAlbum && cover) && files[path 'folder.jpg'] := cover

    while pos := RegExMatch(html, '{(&quot;)(mp3-128)\1:\1(https://.+?.bcbits.com/.+?/\2/.+?)\1}.+?title\1:\1(.+?)\1.+?track_num\1:([\w]+)', &m, pos) {
      pos += StrLen(m[])
      f := path (m.5 = 'null' ? '' : (m.5 < 10 ? 0 : '') m.5 ' - ') filter(m.4) (!isAlbum && year ? ' (' year ')' : '') '.mp3'
      files[f] := StrReplace(m.3, '&amp;', '&')
    }

    tip '{} – {}{}`nЗагрузка {} …', artist, release, isAlbum ? ' (' year ')' : '', isAlbum ? 'альбома (треки: ' amount ')' : 'трека', amount

    for f, url in files {
      SplitPath f, &name,, &ext
      if FileExist(f) {
        tip '{}`nТрек уже скачан.', name
        continue
      }
      isTrack := ext = 'mp3'
      title := isTrack ? name : release
      try download url, f
      catch {
        tip '{}{}`nНевозможно загрузить {}.', title, isAlbum ? ' (' year ')' : '', isTrack ? 'трек' : 'обложку'
        continue
      }
      tip '{}`n{}', title, isTrack ? 'Трек загружен.' : 'Обложка загружена.'
    }
    (isAlbum) && tip('{} – {} ({})`nАльбом полностью скачан.', artist, release, year)
  }
  (isMusic) && tip('{} (релизы: {})`nСкачивание дискографии завершено.', musicPage, releases.length)

  releases := []
  end:
  A_ClipBoard := ''
}

filter(txt) {
  static xml := map('&(amp|#38);', '&', '&(gt|62);', '›', '&(lt|60);', '‹', '&(quot|#34|apos|#39);', '`'',)
  static chars := map('<','‹','>','›',':','꞉','"','“','/','∕','\','∖','|','⼁','?','？','*','＊')
  for f, a in xml
    txt := RegExReplace(txt, f, a)
  for f, a in chars
    txt := StrReplace(txt, f, a)
  return txt
}