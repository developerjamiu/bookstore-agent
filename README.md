# Music Store Agent — Build Your First AI Agent with Genkit

> **This `starter` branch** (typical **fork** clone) is the **codelab starting point**: Flutter + Dart server skeleton + **Node.js skeleton** under `packages/nodejs_server/` with placeholder APIs.  
> **Full solution** (completed Dart + Node agents, server tests): [`developerjamiu/music-store-agent`](https://github.com/developerjamiu/music-store-agent) branch **`main`**.

A hands-on codelab project where you build a **real AI agent** — an LLM that
autonomously explores a database using tools it chooses, writes SQL queries,
and answers natural-language questions about a music store.

The agent doesn't just generate text. It **thinks, acts, observes, and
decides** what to do next — the core loop that makes something an agent
rather than a chatbot.

## What You'll Build

```
┌──────────────┐    POST /api/research     ┌──────────────────────┐
│  Flutter UI  │ ────────────────────────►  │  Shelf Server :8080  │
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
2. Call `describeTable` on `customers`, `invoices`, `invoice_lines`, `tracks`
3. Write and run a SQL query to find the top spender
4. Run a second query to find what they bought
5. Synthesize a natural-language answer with the SQL sources

Every tool call is a **decision the model made** — visible in the UI's
"Agent trace" panel.

## Technology Stack

| Layer        | Technology                                                  |
| ------------ | ----------------------------------------------------------- |
| AI Framework | [Genkit for Dart](https://github.com/genkit-ai/genkit-dart) **or** [Genkit JS](https://genkit.dev/docs/js/get-started/) (Node track) |
| LLM          | Google Gemini — set `GOOGLE_API_KEY` or `GEMINI_API_KEY`    |
| Server       | **Dart:** Shelf (`packages/server`) **·** **Node:** `packages/nodejs_server` |
| Database     | SQLite file `packages/server/data/music_store.db` (Dart track & Node final wiring) |
| Client       | Flutter (Material 3) — `POST /api/research` on port **8080** |

**Codelabs:** [CODELAB.md](./CODELAB.md) (Dart) · [CODELAB-NodeJS.md](./CODELAB-NodeJS.md) (Node — reference code lives on upstream **`main`**).

## Repository Structure

```
research_assistant/
├── pubspec.yaml                         # Dart workspace root
├── README.md
├── CODELAB.md
├── CODELAB-NodeJS.md
│
├── packages/
│   ├── nodejs_server/
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts                 # Listens on 8080; forwards POST /api/research
│   │       ├── middleware/
│   │       │   └── cors.ts              # CORS headers + OPTIONS preflight
│   │       ├── routes/
│   │       │   └── research.ts          # Validates JSON body; returns placeholder result
│   │       └── utils/
│   │           └── requestHelpers.ts    # jsonResponse, errorResponse, handleGenkitError (for later)
│   ├── server/
│   │   ├── bin/server.dart              # Shelf server entrypoint
│   │   ├── data/music_store.db          # Pre-seeded SQLite database
│   │   ├── lib/src/
│   │   │   ├── agent/
│   │   │   │   ├── research_agent.dart  # Two-phase agent: tool loop + synthesis
│   │   │   │   └── setup.dart           # Composition root (DI wiring)
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
│   │           └── helpers/             # In-memory test database
│   │
│   └── client/                          # Flutter app
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
| `main`    | **Upstream repo only** — complete Dart + Node + Flutter + docs                                |
| `starter` | **This branch** — placeholders + skeletons; you implement the agent via the codelabs        |

## Prerequisites

- **Dart SDK** >= 3.11 (`dart --version`)
- **Flutter SDK** >= 3.27 (`flutter --version`)
- **Node.js** >= 20 — for `packages/nodejs_server` only
- **Google AI API key** — [aistudio.google.com/apikey](https://aistudio.google.com/apikey) (`GOOGLE_API_KEY` / `GEMINI_API_KEY`; never commit keys)
- **SQLite Viewer** (optional) — [VS Code extension](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer)

## Getting Started

### 1. Clone and install dependencies

```sh
git clone git@github.com:developerjamiu/music-store-agent.git
cd music-store-agent
dart pub get
```

### 2. Explore the database

Open `packages/server/data/music_store.db` in VS Code with the SQLite Viewer
extension. You'll see 9 tables with real data:

| Table           | Rows | Description                                       |
| --------------- | ---- | ------------------------------------------------- |
| artists         | 15   | AC/DC, Queen, Miles Davis, Adele, etc.            |
| albums          | 20   | Back in Black, Abbey Road, Kind of Blue, etc.     |
| tracks          | 52   | Bohemian Rhapsody, Stairway to Heaven, etc.       |
| genres          | 7    | Rock, Jazz, Metal, Pop, Reggae, Electronic, Blues |
| customers       | 10   | International customers                           |
| invoices        | 15   | Purchase records                                  |
| invoice_lines   | 98   | Individual track purchases                        |
| playlists       | 3    | Road Trip Rock, Chill Jazz, Party Anthems         |
| playlist_tracks | 19   | Playlist memberships                              |

### 3. Run the tests (no API key needed)

```sh
# Client — mock HTTP
cd packages/client && flutter test
```

On **`starter`**, the Dart server package does not yet include the full agent test suite (that lives on upstream **`main`**).

### 4. Start a backend (one at a time on port 8080)

**Dart (Shelf) — placeholder response:**

```sh
dart run packages/server/bin/server.dart
```

**Node — placeholder response (no API key required for the shell):**

```sh
cd packages/nodejs_server && npm install && npm start
```

**Full agent + tests** — clone upstream **`main`**: [music-store-agent](https://github.com/developerjamiu/music-store-agent).

### 4b. Dart server with API key (after you complete the Dart codelab)

```sh
export GOOGLE_API_KEY=your-key-here
dart run packages/server/bin/server.dart
```

You'll see:

```
Server running on http://localhost:8080

Try it:
  curl -s http://localhost:8080/api/research \
    -H "Content-Type: application/json" \
    -d '{"question":"Which genre has the most tracks?"}' | jq
```

### 5. Test with curl

```sh
# Simple lookup
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What artists are in the database?"}' | jq

# Requires multi-table JOINs — watch the toolCalls array
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"Who is the top spending customer and what did they buy?"}' | jq

# Many-to-many relationship
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What songs are in the Chill Jazz playlist?"}' | jq

# Out of scope — agent should gracefully refuse
curl -s http://localhost:8080/api/research \
  -H 'Content-Type: application/json' \
  -d '{"question":"What is the weather today?"}' | jq
```

### 6. Run the Flutter app

With the server running:

```sh
cd packages/client
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

### Two-phase generate pattern

Gemini doesn't support `tools` + `outputSchema` in the same API call. The
agent works around this with two separate calls:

1. **Research phase** — tools enabled, `maxTurns: 10`, model explores freely
2. **Synthesis phase** — `outputSchema` enabled, model produces structured
   JSON from the research notes

## What the Starter Branch Contains

### Pre-built (you don't modify these)

- **Flutter client** — complete, working UI with answer card, tool trace panel,
  loading states, error handling, and "New question" reset
- **Dart server scaffolding** — `packages/server`: `bin/server.dart`, CORS,
  `request_helpers.dart`, placeholder `POST /api/research`
- **Node server scaffolding** — `packages/nodejs_server`: HTTP server, CORS,
  placeholder `POST /api/research` (see **Repository Structure**). No SQLite or Genkit flows yet.
- **SQLite database** — `packages/server/data/music_store.db` pre-seeded with all 9 tables
- **Pubspec files** — all dependencies already configured
- **Client tests** — unit, widget, and integration tests (all passing)

### What you build from scratch

| What                                                                                                                            | Why                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Schemas** — `table_name_input.dart`, `sql_query_input.dart`, `research_output.dart`, `research_result.dart`, `tool_call.dart` | Define the data shapes the agent works with using Schemantic                  |
| **Tools** — `list_tables.dart`, `describe_table.dart`, `run_query.dart`                                                         | Write the logic AND register each tool with Genkit via `ai.defineTool()`      |
| **Message helpers** — `message_helpers.dart`                                                                                    | Extract tool calls and build research notes from Genkit conversation messages |
| **Agent** — `research_agent.dart`                                                                                               | Build the two-phase generate: tool-calling loop + structured synthesis        |
| **Setup** — `setup.dart`                                                                                                        | Wire everything together in the composition root                              |
| **Route update** — `research.dart`                                                                                              | Replace the placeholder response with the real agent flow                     |
| **Agent tests** — `research_agent_test.dart`                                                                                    | Test the agent using `ai.defineModel()` with fake responses                   |
| **Tool tests** — `list_tables_test.dart`, `describe_table_test.dart`, `run_query_test.dart`                                     | Test each tool's logic method against a real in-memory database               |

### The codelab experience

1. **Before the codelab** — start the server, open the app, ask a question →
   you get placeholder data ("This is a placeholder response...")
2. **During the codelab** — build schemas, tools, agent, tests step by step
3. **After the codelab** — ask the same question → a real AI agent explores
   the database, runs SQL, and answers with sources and a full tool trace

## Key Concepts Covered

- **Genkit tools** — `ai.defineTool()` with typed input/output schemas
- **Genkit flows** — `ai.defineFlow()` for composable, traceable operations
- **Agentic tool loop** — `maxTurns`, autonomous tool selection, termination
- **Two-phase generate** — separating tool calling from structured output
- **Fake model testing** — `ai.defineModel()` for deterministic tests without API calls
- **Constructor DI** — every class receives dependencies via constructor
- **Composition root** — one place wires everything together
