# Quick Start - VidiMate Backend Server

## One-Command Start

```bash
cd F:\vidimate_backend
python main.py
```

Server will start at: `http://0.0.0.0:8000`

## Verify Server is Running

```bash
curl http://localhost:8000/
# Expected: {"status": "VidiMate Backend Running", "version": "1.0.2"}
```

Or in browser: open `http://localhost:8000/`

## Connect Flutter App

Update `api_client.dart` to use local backend:

```dart
await ApiClient.initialize(baseUrl: 'http://10.0.2.2:8000');
```

- **Emulator**: use `10.0.2.2` (localhost inside emulator)
- **Physical device**: use your computer's local IP (e.g., `192.168.1.x`)

## Test Endpoints

### Trending Videos
```bash
curl "http://localhost:8000/api/discover/trending"
```

### Search Videos
```bash
curl "http://localhost:8000/api/discover/search?q=flutter"
```

### Extract URL
```bash
curl -X POST http://localhost:8000/api/extract -d '{"url": "https://www.youtube.com/watch?v=test"}'
```

### Download Status
```bash
curl http://localhost:8000/api/downloads/some-job-id
```

## Stop the Server

Press `Ctrl+C` in the terminal where the server is running.

## Auto-Start (Optional)

Add to your startup or use a process manager:

```bash
# Keep running in background
nohup python main.py > /tmp/vidimate.log 2>&1 &

# Or use systemd (Linux) or Windows Task Scheduler
```

## Common Issues

1. **Port already in use**: Change port in `main.py` line 65: `port=8001`
2. **CORS errors**: Add headers if needed for browser-based testing
3. **Flutter can't connect**: 
   - Emulator: verify `10.0.2.2` works
   - Physical device: use your computer's actual IP address on the same network
4. **Flutter shows mock data**: Ensure `ApiClient.initialize()` is called before making API calls

## Development Workflow

1. Start backend: `python main.py`
2. Run Flutter app: `cd F:\VidiMate-App && flutter run`
3. Test discover/download features
4. Make backend changes → server auto-reloads (reload=True)
5. Hot reload Flutter app to see changes