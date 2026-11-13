import 'package:relic/relic.dart';

import 'middleware/cors.dart';

/// Runs [cors] and [logRequests] in front of every request to [routes].
///
/// Middleware added with `use` only runs for requests that match a route,
/// so [routes] is mounted as the only route: `any` matches every method and
/// `/**` matches every path. That way the 404 and 405 answers of [routes]
/// get CORS headers and a log line too.
RelicApp buildApp(RelicRouter routes, {Logger? logger}) {
  return RelicApp()
    ..use('/', cors())
    ..use('/', logRequests(logger: logger))
    ..any('/**', routes.asHandler);
}
