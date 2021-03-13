import 'dart:io';

import 'package:csv/csv.dart';
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
          'url'
        ];

        results.add([
          package.package,
          metrics.scorecard.packageVersion,
          info.versions.last.version,
          metrics.score.popularityScore.formatPercent(),
          metrics.score.likeCount.toString(),
          info.url,
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

  /// Save CSV
  final csv = ListToCsvConverter().convert([header, ...results]);
  final csvFile = File('results/csv/${DateTime.now().formatSimple()}.csv');
  await csvFile.create(recursive: true);
  await csvFile.writeAsString(csv);

  /// Print table
  final table = tabulate(results, header);
  print(table);

  /// Save table
  final markdownTable = table.split('\n').map((e) => '|$e|').join('\n');
  final tableFile = File('results/table/${DateTime.now().formatSimple()}.md');
  await tableFile.create(recursive: true);
  await tableFile.writeAsString(markdownTable);
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
}
