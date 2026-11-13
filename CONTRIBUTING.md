# Contributing

## Opening a pull request upstream

If you cloned a **fork** for the codelab and want to contribute improvements back to the original [bookstore-agent](https://github.com/developerjamiu/bookstore-agent) repository:

1. Add the upstream remote if needed: `git remote add upstream git@github.com:developerjamiu/bookstore-agent.git`
2. Create a branch from the latest `main`: `git fetch upstream && git checkout -b my-feature upstream/main`
3. Make your changes, run tests (`dart test packages/dart_server`, `cd packages/client && flutter test`, and Node checks if you changed `packages/nodejs_server`), and commit with clear messages.
4. Push your branch to your fork: `git push -u origin my-feature`
5. Open a **pull request** from your fork into `developerjamiu/bookstore-agent:main` and describe what changed and why.
