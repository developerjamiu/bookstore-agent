# Other languages

The main project is the Dart server in `packages/dart_server`. This folder holds the same server written in other languages, so the Flutter app can talk to any of them.

| Folder | Language | Framework |
| --- | --- | --- |
| [`nodejs_server`](nodejs_server) | TypeScript (Node.js) | [Genkit JS](https://genkit.dev/docs/js/get-started/) |

## Adding a port

A port of the server (for example `python_server`) must:

- serve `POST /api/research` on port 8080 (or `PORT`) with CORS, taking `{"question": "..."}` and returning `{"answer", "sources", "confidence", "toolCalls"}`;
- answer errors as `{"error": "..."}` with 400 for a bad request, 429 when the API quota runs out, 503 when the model is overloaded, and 500 otherwise;
- read the shared database at `packages/dart_server/data/bookstore.db`;
- give the model the same three tools (`listTables`, `describeTable`, `runQuery`) and the same prompt and rules as `packages/dart_server/lib/src/agent/research_agent.dart`.

Then add a row to the table above and a link in the main README.
