# B1: Provider silently retries HTTP 429 and 503, with no setting and no signal to the caller

- **Build:** IRIS for Health Community 2026.3.0AI.154.0 (container `irishealth-community:2026.3.0AI.154.0`)
- **Component:** `%AI.Provider` (`openai` provider) / `%AI.Agent.Chat`
- **API key needed:** no (a local fake server stands in for the provider)

## Steps

1. Start a fake OpenAI-style server inside the container. It answers every request with the status given in the URL path and logs the time of each request:

   ```shell
   docker exec -it <container> bash
   cat > /tmp/fake_llm.py <<'EOF'
   import http.server, json, time

   class Handler(http.server.BaseHTTPRequestHandler):
       def log_message(self, *args):
           pass

       def do_POST(self):
           self.rfile.read(int(self.headers.get("Content-Length", 0)))
           with open("/tmp/fake_llm.log", "a") as log:
               log.write("%.3f %s\n" % (time.time(), self.path))
           status = 429 if self.path.startswith("/r429") else 503
           body = json.dumps({"error": {"message": "fake %d" % status, "type": "server_error"}}).encode()
           self.send_response(status)
           self.send_header("Content-Type", "application/json")
           self.send_header("Content-Length", str(len(body)))
           self.end_headers()
           self.wfile.write(body)

   http.server.ThreadingHTTPServer(("127.0.0.1", 18080), Handler).serve_forever()
   EOF
   python3 /tmp/fake_llm.py &
   ```

2. In an IRIS terminal (`iris session IRIS`, any namespace):

   ```objectscript
   set provider = ##class(%AI.Provider).Create("openai", {"api_key": "dummy", "base_url": "http://127.0.0.1:18080/r503/v1"})
   set agent = ##class(%AI.Agent).%New(provider), agent.Model = "m"
   do agent.%Init()
   set session = agent.CreateSession({"max_iterations": 1})
   set start = $ZHorolog
   try { do agent.Chat(session, "hi") } catch e { write e.DisplayString(), ! }
   write $ZHorolog - start, " s", !
   ```

3. `cat /tmp/fake_llm.log`. Repeat with `/r429/v1` in `base_url`.

## Expected

One request, or a documented retry policy that the caller can turn off or limit (for example a provider or session setting), and some sign that retries happened (a count, a warning, or the last `Retry-After`). A caller with its own deadline cannot plan around retries it does not know about.

## Actual

- The fake server receives **4 requests per `Chat`**, about 0.5 s, 1 s and 2 s apart, for both 503 and 429.
- `Chat` throws only after the last one: `<%AICore>ProviderError: Provider 'openai' error: API error: [server_error] fake 503`, after 3.5 to 3.8 s in total (two runs).
- Nothing tells the caller that it retried. No `CreateSession` key and no documented provider setting controls this. The class comments of `Chat` and `CreateSession` do not mention retries.
- With a real Gemini key on the free tier, a quota 429 took 27.7 s to come back. To the caller this looked like a slow provider, not like a quota error.
