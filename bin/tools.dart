import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pub_api_client/pub_api_client.dart';
import 'package:tabulate/tabulate.dart';

void main(List<String> arguments) async {
  final stopwatch = Stopwatch()..start();

  const max = 100;
  var page = 1;

  final client = PubClient();

  var header = <String>[];

  final results = <List<String>>[];

  Future<void> recurse() async {
    if (results.length >= max) return;

    final searchResults = await client.search('', page: page);

    for (var package in searchResults.packages) {
      final info = await client.packageInfo(package.package);
      final metrics = await client.packageMetrics(package.package);

      final releaseIsNullSafe = metrics.isNullSafe;
      final lastReleaseIsNullSafe =
          info.versions.last.version.contains('nullsafety');

      if (releaseIsNullSafe == false && lastReleaseIsNullSafe == false) {
        header = [
          'package',
          'release version',
          'last version',
          'popularity',
          'likes',
        ];

        results.add([
          '[${package.package}](${info.url})',
          metrics.scorecard.packageVersion,
          info.versions.last.version,
          metrics.score.popularityScore.formatPercent(),
          metrics.score.likeCount.toString(),
        ]);
      }
    }

    print('Scanned page $page, found ${results.length} so far');

    page++;
    await recurse();
  }

  await recurse();

  /// Print summary
  print('After $page pages '
      'we found ${results.length} results '
      'in ${stopwatch.elapsed.formatSimple()}'
      '\n');

  /// Print table
  final table = tabulate(results, header);
  print(table);

  /// Save table
  final markdownTable = table.wrapLinesWithPipes();
  final tableFile = File('results/${DateTime.now().formatSimple()}.md');
  await tableFile.create(recursive: true);
  await tableFile.writeAsString(markdownTable);

  /// Save latest
  final markdownFile = File('latest-packages.md');
  await markdownFile.create(recursive: true);
  await markdownFile.writeAsString([
    '# ${results.length} Popular Unsafe Dart Packages',
    '### Updated ${DateTime.now().formatPretty()}',
    '',
    markdownTable,
  ].join('\n'));
}

enum NullSafety { release, prerelease, none }

extension on PackageMetrics {
  bool get isNullSafe => scorecard.derivedTags.contains('is:null-safe');

  // sdk:dart|sdk:flutter|platform:android|platform:ios|platform:windows|platform:linux|platform:macos|platform:web|runtime:native-aot|runtime:native-jit|runtime:web
}

extension on num {
  String formatPercent() => '${(this * 100).round()}%';
}

extension on Duration {
  String formatSimple() => '$inMinutes:$inSeconds';
}

extension on DateTime {
  String formatSimple() => DateFormat('yyyy-MM-dd').format(this);
  String formatPretty() => DateFormat(DateFormat.YEAR_MONTH_DAY).format(this);
}

extension on String {
  String wrapLinesWithPipes() => [
        for (var e in split('\n'))
          if (e.trim().isEmpty == false) '|$e|'
      ].join('\n');
}
