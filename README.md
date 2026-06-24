# Studio — Operations Guide (media.divafans.club)

A self-hosted live broadcasting studio. Performers go live from a web browser (no app
to install), the admin watches and manages, every session records automatically and
uploads to Bunny storage for playback.

---

## PART 1 — FOR PERFORMERS

You need two things from the admin: the website address and your login.

### Going live
1. Open **https://media.divafans.club/studio/** in Chrome (works on laptop or phone).
2. Log in with the username and password your admin gave you.
3. Go to the broadcast page: **https://media.divafans.club/live**
4. Allow camera and microphone when the browser asks.
5. Choose your camera and mic from the two dropdowns.
6. Click **Go Live**. The button turns red and shows "You are live."
7. To stop, click **End broadcast** (or just close the tab).

### Tips
- Use a strong, steady internet connection. WiFi is better than cell data for 1080p.
- Allow camera/mic permission or the page can't broadcast.
- Only one performer can be live at a time. Make sure the previous show has ended.
- If it says "Please log in first," your session expired — log in again at /studio/.
- If it says "Could not connect," check your internet and try again.

---

## PART 2 — FOR THE ADMIN

### Your pages
| Page | Address | What it's for |
|------|---------|---------------|
| Console | https://media.divafans.club/studio/ | Watch the live stream, chat, timers, End broadcast |
| Accounts | https://media.divafans.club/studio/models.html | Create / remove performer & admin accounts |
| Owncast admin | https://media.divafans.club/admin | Stream settings, video quality, chat moderation (login: admin / your password) |

### Creating a performer account
1. Log in at **/studio/** as your admin account.
2. Open **/studio/models.html** (or the Accounts link in the sidebar).
3. Enter a username and password, choose role **Performer**, click **Add**.
4. Give that username + password and the address **media.divafans.club/studio/** to the performer.

### Running a show
- Open the console at **/studio/**. When a performer goes live, their video appears,
  the **On Air** light comes on, chat enables, and recording starts automatically.
- **End broadcast** (admin button, shown when live) cuts the stream server-side.
- Recordings appear in the **Recordings** panel and play back from Bunny CDN.

### Recordings
- Every live session records automatically (one file per session).
- Files upload to your Bunny storage zone **live-media** and are then removed from the
  server to save disk. View/play them from the **Recordings** panel in the console.

---

## PART 3 — SYSTEM REFERENCE (technical)

### Architecture
```
performer browser (camera)
   │  WebRTC / WHIP  (HTTPS signaling + UDP 8189 media)
   ▼
MediaMTX  (/opt/mediamtx)  — accepts the browser feed on path "live"
   │  ffmpeg bridge (runOnReady): RTSP -> RTMP, video copy, audio -> AAC
   ▼
Owncast  (/opt/owncast/owncast)  — RTMP ingest on :1935, HLS, chat, recording
   │
   ├─ nginx (HTTPS) serves console at /studio/ and proxies the rest
   ├─ recorder (owncast-recorder) -> /opt/owncast/recordings/*.mp4
   └─ bunny-offload (timer) -> uploads recordings to Bunny, clears local
```

### Services (all auto-start on boot)
| Service | Role | Check |
|---------|------|-------|
| owncast | ingest, HLS, chat, recording | `systemctl status owncast` |
| mediamtx | browser (WHIP) ingest + bridge | `systemctl status mediamtx` |
| nginx | HTTPS, serves console, proxies | `systemctl status nginx` |
| php-fpm | login / accounts / API | `systemctl status php-fpm` |
| bunny-offload.timer | ships recordings to Bunny | `systemctl status bunny-offload.timer` |

### Key file locations
| What | Path |
|------|------|
| Console UI | /opt/owncast/webroot/studio/index.html |
| Go Live page | /opt/owncast/webroot/studio/golive.html  (served at /live) |
| Accounts page | /opt/owncast/webroot/studio/models.html |
| Login / API code | /opt/owncast/webroot/studio/api/*.php |
| Accounts (hashed) | /opt/owncast/private/users.json |
| App config | /opt/owncast/private/config.php  (stream key, Bunny pull zone) |
| MediaMTX config | /opt/mediamtx/mediamtx.yml |
| nginx site | /etc/nginx/conf.d/studio.conf |
| Bunny offload config | /etc/bunny-offload.conf |
| Recordings (temp) | /opt/owncast/recordings/ |

### Important values
- Domain: media.divafans.club  (HTTPS via Let's Encrypt, auto-renews)
- Owncast stream key: in /opt/owncast/private/config.php (used by the bridge + End broadcast)
- Ports: 80/443 (web), 1935 (RTMP, internal), 8189/udp (WebRTC media), 8080/8889/8554/9997 (internal)

### Manage accounts from the command line (alternative to the web page)
```
studio-adduser <username> performer      # add/replace a performer
studio-adduser <username> admin           # add/replace an admin
```

### Common checks
```
# is a stream live?
curl -s http://127.0.0.1:8080/api/status | python3 -m json.tool | grep online

# is the browser->Owncast bridge running (only while someone is live)?
pgrep -a ffmpeg

# did a recording upload to Bunny?
journalctl -t bunny-offload -n 10
```

### If a performer can't go live
1. Confirm they are logged in at /studio/ first (the broadcast page requires it).
2. Confirm only one person is trying to broadcast (single-stream system).
3. On the server: `systemctl status mediamtx owncast` — both must be `active`.
4. Watch the bridge while they click Go Live: `journalctl -u mediamtx -f`

### Privacy
- The site returns `noindex` and blocks robots, so search engines won't list it.
- Access still requires the URL + a login; it is unlisted, not IP-restricted.

---

## NOT INCLUDED / FUTURE
- Multiple performers broadcasting simultaneously (current design is one-at-a-time;
  that would be a different multi-room build).
- A single "Go Live" button inside the console (performers currently use the /live page).
- HLS latency tuning (Owncast admin -> Configuration -> Video) to reduce the delay.
