# Deploy ENDLESS CAM / STUDIO

## Important split

| Component | Where it runs |
|-----------|----------------|
| `endless_engine.py` (virtual cam) | **Your PC only** — needs webcam + v4l2/pyvirtualcam |
| Flutter UI | Desktop/mobile/web local or static host |
| `virtual_cam_bridge.py` / WHIP / WebRTC helpers | Optional on a **free Python host** for remote API experiments |

Virtual camera into Zoom/Teams **cannot** run in the cloud. Deploy the **bridge** only if you need a public HTTP API; keep the engine local.

---

## Fast free Python hosts (bridge API)

### 1) Render (free tier) — simplest

1. Push this repo to GitHub  
2. https://render.com → **New → Web Service** → connect repo  
3. Root directory: `bridge`  
4. Build: `pip install -r requirements.txt`  
5. Start: `python virtual_cam_bridge.py`  
6. In `virtual_cam_bridge.py` ensure `app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8766)))`  

Free tier spins down after idle; fine for demos.

### 2) Railway (free trial / hobby)

1. https://railway.app → New Project → Deploy from GitHub  
2. Set root to `bridge`  
3. Start command: `python virtual_cam_bridge.py`  
4. Add env `PORT` (Railway injects it)

### 3) Fly.io

```bash
# install flyctl, then:
cd bridge
fly launch
fly deploy
```

### 4) Hugging Face Spaces (Docker/Gradio) — good for demos

Create `Dockerfile` in `bridge/` and Space SDK Docker; expose port 7860/8766.

### 5) PythonAnywhere / Glitch

Possible for Flask, but cold starts and no GPU; OK for tiny API only.

---

## Local “deploy” (real product — recommended)

```bash
unzip ENDLESS_CAM_STUDIO.zip
cd endless_cam_studio/bridge
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python endless_engine.py --camera 0
```

Linux: see `INSTALL_LINUX.md` + `WAYLAND_VIRTUAL_CAM.md`.

---

## Patch bridge for cloud host binding

If deploying Flask to Render/Railway, bind:

```python
port = int(os.environ.get("PORT", 8766))
app.run(host="0.0.0.0", port=port, threaded=True)
```

Never expose stream keys publicly; use HTTPS and secrets.
