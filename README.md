# Bookstore Agent — Build Your First AI Agent with Genkit

A hands-on codelab project where you build a **real AI agent** — an LLM that
autonomously explores a database using tools it chooses, writes SQL queries,
and answers natural-language questions about a bookstore.

The agent doesn't just generate text. It **thinks, acts, observes, and
decides** what to do next — the core loop that makes something an agent
rather than a chatbot.

## What You'll Build

```
┌──────────────┐    POST /api/research     ┌──────────────────────┐
│  Flutter UI  │ ────────────────────────►  │  Relic Server :8080  │
│              │                           │                      │
│  - question  │    { answer, sources,     │  ┌────────────────┐  │
│  - answer    │ ◄── confidence,           │  │ ResearchAgent  │  │
│  - queries   │      toolCalls }          │  │                │  │
│  - trace     │                           │  │ listTables     │  │
└──────────────┘                           │  │ describeTable  │  │
                                           │  │ runQuery       │  │
                                           │  └────────────────┘  │
                                           └──────────────────────┘
```

Ask a question like _"Who is the top spending customer?"_ and watch the agent:

1. Call `listTables` to discover the database schema
2. Call `describeTable` on `customers`, `orders`, `order_items`, `books`
3. Write and run a SQL query to find the top spender
4. Run a second query to find what they bought
5. Synthesize a natural-language answer with the SQL sources

Every tool call is a **decision the model made** — visible in the UI's
"Agent trace" panel.

## Technology Stack

| Layer        | Technology                                                  |
| ------------ | ----------------------------------------------------------- |
| AI Framework | [Genkit for Dart](https://github.com/genkit-ai/genkit-dart) |
| LLM          | Google Gemini (via `genkit_google_genai`)                   |
| Server       | [Relic](https://docs.dartrelic.dev/) (Dart) or Node.js HTTP server (`packages/dart_server` · `packages/nodejs_server`) |
| Database     | SQLite (in-process, no server needed)                       |
| Schemas      | Schemantic (code-generated JSON schemas)                    |
| Client       | Flutter (Material 3)                                        |
| Testing      | Fake models via `ai.defineModel()` — no mocking libraries   |

**Node.js backend (optional):** same HTTP API for the Flutter client. Use [Genkit for JavaScript](https://genkit.dev/docs/js/get-started/) with `@genkit-ai/google-genai`, **Zod** schemas via `genkit`, **`better-sqlite3`**, and TypeScript in `packages/nodejs_server/`.

## Repository Structure

```
bookstore-agent/
├── pubspec.yaml                         # Dart workspace root
├── README.md
│
├── packages/
│   ├── nodejs_server/                   # Node + Genkit (TypeScript) — same /api/research API
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts                 # HTTP server; opens SQLite; wires research flow
│   │       ├── middleware/
│   │       │   └── cors.ts              # CORS headers + OPTIONS preflight
│   │       ├── routes/
│   │       │   └── research.ts          # POST /api/research; validates JSON; calls agent flow
│   │       ├── schemas/
│   │       │   └── researchResult.ts    # Zod: ResearchResult, tool calls, synthesis output
│   │       ├── tools/
│   │       │   ├── listTables.ts        # Tool: list SQLite tables
│   │       │   ├── describeTable.ts     # Tool: PRAGMA schema / FKs for one table
│   │       │   └── runQuery.ts          # Tool: read-only SELECT (row cap)
│   │       ├── utils/
│   │       │   ├── requestHelpers.ts    # JSON responses + Genkit error mapping
│   │       │   └── messageHelpers.ts     # Extract tool calls; build research notes for synthesis
│   │       └── agent/
│   │           ├── researchAgent.ts      # Two-phase agent: tool loop + structured synthesis
│   │           └── setup.ts             # Composition root: Genkit + tools + flow
│   │
│   ├── dart_server/
│   │   ├── bin/server.dart              # Relic server entrypoint
│   │   ├── data/bookstore.db            # Pre-seeded SQLite database
│   │   ├── lib/src/
│   │   │   ├── agent/
│   │   │   │   ├── research_agent.dart  # Agent: tool loop + JSON answer
│   │   │   │   └── setup.dart           # Creates the tools and the agent
│   │   │   ├── tools/
│   │   │   │   ├── list_tables.dart     # Tool: discover database tables
│   │   │   │   ├── describe_table.dart  # Tool: inspect table schema
│   │   │   │   └── run_query.dart       # Tool: execute read-only SQL
│   │   │   ├── schemas/                 # Schemantic input/output schemas
│   │   │   ├── routes/research.dart     # POST /api/research handler
│   │   │   ├── middleware/cors.dart
│   │   │   └── utils/
│   │   │       ├── request_helpers.dart
│   │   │       └── message_helpers.dart # Extract tool calls from messages
│   │   └── test/
│   │       └── src/
│   │           ├── agent/               # Agent tests (fake model)
│   │           ├── tools/               # Tool unit tests
│   │           ├── utils/               # Message helper tests
│   │           ├── routes/              # Route tests (fake flows, in-process server)
│   │           ├── middleware/          # CORS middleware tests
│   │           └── helpers/             # In-memory test database, in-process server
│   │
│   └── flutter_app/                     # Flutter app
│       ├── lib/src/
│       │   ├── app.dart
│       │   ├── screens/research_screen.dart
│       │   ├── widgets/
│       │   │   ├── answer_card.dart
│       │   │   └── tool_call_list.dart
│       │   └── services/research_api.dart
│       ├── test/                        # Unit + widget tests
│       └── integration_test/            # Full-flow integration test
```

## Branch Structure

| Branch    | Purpose                                                                                       |
| --------- | --------------------------------------------------------------------------------------------- |
| `main`    | Complete, working project — the reference solution                                            |
| `starter` | Starting point for the codelab — UI works with placeholder data, agent is not yet implemented |

## Prerequisites

- **Flutter SDK** with Dart 3.12 or later (`flutter --version`)
- **iOS Simulator or Android emulator** (Xcode or Android Studio), to run the Flutter app
- **Google AI API key** — get one free at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) (set `GOOGLE_API_KEY` for Dart; `GEMINI_API_KEY` or `GOOGLE_API_KEY` for Node — never commit keys)
- **Node.js** >= 20 (`node --version`) — only if you run `packages/nodejs_server`
- **SQLite Viewer** (optional) — [VS Code extension](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer) to browse the database visually

## Getting Started

### 1. Clone and install dependencies

```sh
git clone https://github.com/developerjamiu/bookstore-agent.git
cd bookstore-agent
flutter pub get
```

### 2. Explore the database

Open `packages/dart_server/data/bookstore.db` in VS Code with the SQLite Viewer
extension. You'll see 9 tables with real data:

| Table              | Rows | Description                                           |
| ------------------ | ---- | ----------------------------------------------------- |
| authors            | 15   | Jane Austen, Charles Dickens, Jules Verne, etc.       |
| publishers         | 5    | Harbor Press, Northwind Books, etc.                   |
| books              | 52   | Pride and Prejudice, Treasure Island, Longitude, etc. |
| genres             | 7    | Classics, Mystery, Science Fiction, History, etc.     |
| customers          | 10   | International customers                               |
| orders             | 15   | Purchase records                                      |
| order_items        | 98   | Individual book purchases                             |
| reading_lists      | 3    | Summer Reading, Classic Mysteries, Book Club Picks    |
| reading_list_books | 20   | Reading list memberships                              |

### 3. Run the tests (no API key needed)

```sh
# Server: 59 tests using fake models and fake flows
dart test packages/dart_server

# Client — 14 tests using mock HTTP
cd packages/flutter_app && flutter test
```

All tests pass without any Gemini API calls. The server tests use
`ai.defineModel()` to create fake models that simulate the tool-calling loop.
The route tests send requests through the server app in process, with no open
port, to flows that return canned results or fail on purpose.
The client tests use `MockClient` to return canned HTTP responses.

### 4. Start the server

```sh
export GOOGLE_API_KEY=your-key-here
dart run packages/dart_server/bin/server.dart
```

You'll see:

```
Server running on http://localhost:8080
```

The server listens on port 8080 because the Flutter client calls
`http://localhost:8080` (`http://10.0.2.2:8080` on the Android emulator). To
listen on another port, set `PORT` (the Node server reads it too), for example
`PORT=8081 dart run packages/dart_server/bin/server.dart`. The client still
calls 8080, so use another port only for curl testing.

### 4b. Start the Node.js server (alternative backend)

Use **either** the Dart server **or** the Node server on port **8080** — not both at once. The Node app reads the same database file: `packages/dart_server/data/bookstore.db`.

```sh
cd packages/nodejs_server
npm install
export GEMINI_API_KEY=your-key-here
npm start
```

You should see the same style of startup message and can use the same `curl` examples below against `http://localhost:8080`.

### 5. Test with curl

```sh
# Simple lookup
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What authors are in the database?"}'

# Requires multi-table JOINs — watch the toolCalls array
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"Who is the top spending customer and what did they buy?"}'

# Many-to-many relationship
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What books are on the Summer Reading list?"}'

# Out of scope — agent should gracefully refuse
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What is the weather today?"}'
```

### 6. Run the Flutter app

With the server running, start an iOS Simulator or Android emulator, then:

```sh
cd packages/flutter_app
flutter run
```

The app auto-detects Android emulator vs iOS simulator and sets the correct
server address (`10.0.2.2` for Android emulator, `localhost` for everything
else).

## What Makes This an Agent

An agent is an LLM in a **tool-calling loop**: it decides which tool to call,
sees the result, decides what to do next, and chooses when to stop.

This project demonstrates all three properties:

| Property          | How it works here                                                     |
| ----------------- | --------------------------------------------------------------------- |
| **Tool autonomy** | The model picks between `listTables`, `describeTable`, and `runQuery` |
| **Iteration**     | Multiple turns of think → call tool → observe result → think again    |
| **Termination**   | The model decides "I have enough data" and writes a summary           |

The model **cannot skip the tools** — it has never seen this database. Every
answer must come from actual query results, not the model's training data.

### Tools plus a JSON answer

The agent's `generate` call gets the three tools and `outputSchema`. The
model calls tools as often as it needs (up to `maxTurns: 10`), then replies in
the `ResearchOutput` shape. With Gemini this combination is a preview feature
for Gemini 3 and later models. It was checked live with
`gemini-3.5-flash-lite`. If the model never ran a query,
the answer gets low confidence, and if it hits the turn limit, the agent says
it couldn't finish.

## What the Starter Branch Contains

### Pre-built (you don't modify these)

- **Flutter client** — complete, working UI with answer card, tool trace panel,
  loading states, error handling, and "New question" reset
- **Dart server scaffolding** — `packages/dart_server`: `bin/server.dart`, CORS,
  `request_helpers.dart`, route returning placeholder data
- **Node server scaffolding** (on starter forks) — `packages/nodejs_server` shell with
  placeholder `POST /api/research`; on **`main`** here, the full Node agent matches the Dart reference
- **SQLite database** — `packages/dart_server/data/bookstore.db` pre-seeded with all 9 tables (shared path for Dart and Node on `main`)
- **Pubspec files** — all dependencies already configured
- **Client tests** — unit, widget, and integration tests (all passing)

### What you build from scratch

| What                                                                                                                            | Why                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Schemas** — `table_name_input.dart`, `sql_query_input.dart`, `research_output.dart`, `research_result.dart`, `tool_call.dart` | Define the data shapes the agent works with using Schemantic                  |
| **Tools** — `list_tables.dart`, `describe_table.dart`, `run_query.dart`                                                         | Write the logic AND register each tool with Genkit via `ai.defineTool()`      |
| **Message helpers** — `message_helpers.dart`                                                                                    | List the tools the agent called, for the app's trace                          |
| **Agent** — `research_agent.dart`                                                                                               | Tool-calling loop that ends in a structured JSON answer                       |
| **Setup** — `setup.dart`                                                                                                        | Create the tools and the agent, and connect them                                |
| **Route update** — `research.dart`                                                                                              | Replace the placeholder response with the real agent flow                     |
| **Agent tests** — `research_agent_test.dart`                                                                                    | Test the agent using `ai.defineModel()` with fake responses                   |
| **Tool tests** — `list_tables_test.dart`, `describe_table_test.dart`, `run_query_test.dart`                                     | Test each tool's logic method against a real in-memory database               |

**Node track (`packages/nodejs_server/`):** add Zod schemas, tools, `messageHelpers`, `ResearchAgent`, `setup`, then wire `research.ts` and `index.ts` (same API as Dart for Flutter).

### The codelab experience

1. **Before** — start the server, open the app, ask a question → you get
   placeholder data ("This is a placeholder response...")
2. **While building** — add schemas, tools, agent, tests step by step
3. **After** — ask the same question → a real AI agent explores the database,
   runs SQL, and answers with sources and a full tool trace

## Key Concepts Covered

- **Genkit tools** — `ai.defineTool()` with typed input/output schemas
- **Genkit flows** — `ai.defineFlow()` for composable, traceable operations
- **Agentic tool loop** — `maxTurns`, autonomous tool selection, termination
- **Tools plus structured output**: `generate` with both `tools` and `outputSchema`
- **Fake model testing** — `ai.defineModel()` for deterministic tests without API calls
- **Constructor DI** — every class receives dependencies via constructor
- **Composition root** — one place wires everything together
- **Node parity** — Genkit JS tools + flows; SQLite via `better-sqlite3`; same JSON contract for the Flutter client
