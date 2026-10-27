# B2: Session `timeout_ms` does not stop a slow provider request

- **Build:** IRIS for Health Community 2026.3.0AI.154.0 (container `irishealth-community:2026.3.0AI.154.0`)
- **Component:** `%AI.Agent.CreateSession` (`timeout_ms`) / `%AI.Agent.Chat`
- **API key needed:** no (a local fake server stands in for the provider)

## Steps

1. Start a fake OpenAI-style server inside the container. It waits 20 s, then returns a valid chat completion:

   ```shell
   docker exec -it <container> bash
   cat > /tmp/slow_llm.py <<'EOF'
   import http.server, json, time

   class Handler(http.server.BaseHTTPRequestHandler):
       def log_message(self, *args):
           pass

       def do_POST(self):
           self.rfile.read(int(self.headers.get("Content-Length", 0)))
           time.sleep(20)
           body = json.dumps({
               "id": "x", "object": "chat.completion", "created": 0, "model": "m",
               "choices": [{"index": 0, "message": {"role": "assistant", "content": "ok"}, "finish_reason": "stop"}],
               "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
           }).encode()
           self.send_response(200)
           self.send_header("Content-Type", "application/json")
           self.send_header("Content-Length", str(len(body)))
           self.end_headers()
           self.wfile.write(body)

   http.server.ThreadingHTTPServer(("127.0.0.1", 18081), Handler).serve_forever()
   EOF
   python3 /tmp/slow_llm.py &
   ```

2. In an IRIS terminal:

   ```objectscript
   set provider = ##class(%AI.Provider).Create("openai", {"api_key": "dummy", "base_url": "http://127.0.0.1:18081/v1"})
   set agent = ##class(%AI.Agent).%New(provider), agent.Model = "m"
   do agent.%Init()
   set session = agent.CreateSession({"timeout_ms": 3000, "max_iterations": 1})
   set start = $ZHorolog
   try { set response = agent.Chat(session, "hi")  write response.Content, ! } catch e { write e.DisplayString(), ! }
   write $ZHorolog - start, " s", !
   ```

## Expected

`Chat` gives up at about 3 s with a timeout error, because `timeout_ms` is the limit for the whole agent run.

## Actual

`Chat` returns **successfully after about 20 s** (20.0 and 20.1 s in two runs) with content `ok`. The 3000 ms limit is not applied while a provider request is in flight; it seems to be checked only between iterations. Since a provider call cannot be interrupted from ObjectScript, a caller that needs a real deadline has to run `Chat` in a separate `JOB` and terminate that job.
