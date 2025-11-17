import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ResultsPage extends StatefulWidget {
  final List<Map<String, dynamic>> multiCityQuery;
  final Map<String, String> filters;

  const ResultsPage({
    super.key,
    required this.multiCityQuery,
    required this.filters,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> flights = [];

  static const String apiBase = 'http://156.67.31.137:3000';

  @override
  void initState() {
    super.initState();
    fetchFlights();
  }

  Future<void> fetchFlights() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      flights = [];
    });

    try {
      final List<Map<String, dynamic>> allFlights = [];

      for (final segment in widget.multiCityQuery) {
        final from = Uri.encodeComponent('${segment['from'] ?? ''}');
        final to = Uri.encodeComponent('${segment['to'] ?? ''}');
        final date = Uri.encodeComponent('${segment['date'] ?? ''}');

        // Build query params safely
        final query = <String, String>{
          'from': from,
          'to': to,
          'date': date,
        };

        // merge filters (already strings)
        widget.filters.forEach((k, v) {
          if (v.trim().isNotEmpty) query[k] = Uri.encodeComponent(v);
        });

        // Compose URI (we encoded values above so join manually)
        final sb = StringBuffer('$apiBase/api/flights?');
        final entries = query.entries.map((e) => '${e.key}=${e.value}').toList();
        sb.write(entries.join('&'));
        final url = sb.toString();

        debugPrint('Calling: $url');

        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          // Accept either top-level list or object with `flights` key
          final rawList = decoded is List ? decoded : (decoded['flights'] ?? []);
          if (rawList is List) {
            // normalize all entries to Map<String, dynamic>
            for (final item in rawList) {
              if (item is Map<String, dynamic>) {
                allFlights.add(item);
              } else if (item is Map) {
                // convert to typed map
                allFlights.add(Map<String, dynamic>.from(item));
              }
            }
          }
        } else {
          throw Exception('API returned ${response.statusCode}: ${response.reasonPhrase}');
        }
      }

      // Optionally apply client-side filters (e.g., maxPrice numeric)
      final filtered = _applyClientFilters(allFlights);

      setState(() {
        flights = filtered;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('FetchFlights error: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _applyClientFilters(List<Map<String, dynamic>> list) {
    final result = <Map<String, dynamic>>[];
    final maxPriceRaw = widget.filters['maxPrice'];
    num? maxPrice;
    if (maxPriceRaw != null && maxPriceRaw.isNotEmpty) {
      maxPrice = num.tryParse(maxPriceRaw);
    }

    for (final m in list) {
      if (maxPrice != null) {
        final priceRaw = m['price']?.toString();
        final priceNum = priceRaw != null ? num.tryParse(priceRaw) : null;
        if (priceNum == null || priceNum > maxPrice) continue;
      }
      // carrier filter can already be handled server-side, but double-check
      final carrierFilter = widget.filters['carrier'];
      if (carrierFilter != null && carrierFilter.isNotEmpty) {
        final cc = (m['carrierCode'] ?? m['carrier'] ?? '').toString();
        if (cc.toUpperCase() != carrierFilter.toUpperCase()) continue;
      }
      result.add(m);
    }
    return result;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '—';
    final n = price is num ? price : num.tryParse(price.toString());
    if (n == null) return '—';
    final f = NumberFormat.simpleCurrency(decimalDigits: 0);
    return f.format(n);
  }

  String _extractTime(Map<String, dynamic> flight) {
    // API uses `time` in your sample, but older code used departureTime/arrivalTime — handle both
    final t = flight['time'] ??
        flight['departureTime'] ??
        flight['depTime'] ??
        flight['departure'] ??
        '';
    return t.toString();
  }

  Widget buildFlightCard(Map<String, dynamic> flight) {
    final flightNumber = (flight['flightNumber'] ?? flight['id'] ?? '').toString();
    final carrierName = (flight['carrier'] ?? flight['carrierName'] ?? '').toString();
    final carrierCode = (flight['carrierCode'] ?? flight['carrier_code'] ?? '').toString();
    final from = (flight['from'] ?? '').toString();
    final to = (flight['to'] ?? '').toString();
    final date = (flight['date'] ?? '').toString();
    final time = _extractTime(flight);
    final priceText = _formatPrice(flight['price']);
    final carrierLogo = (flight['carrierLogo'] ?? flight['logo'] ?? '').toString();

    final stops = flight['stops'] is int ? flight['stops'] : (int.tryParse(flight['stops']?.toString() ?? '') ?? 0);
    final stopsText = stops == 0 ? 'Direct' : '$stops stop${stops > 1 ? 's' : ''}';

    // Use carrierLogo if valid; otherwise try a fallback logo URL pattern (optional)
    final logoUrl = (carrierLogo.isNotEmpty) ? carrierLogo : 'https://logos.skyscnr.com/images/airlines/favicon/${carrierCode.toLowerCase()}.png';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showFlightDetails(flight),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            // logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl,
                width: 64,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    width: 64,
                    height: 48,
                    color: const Color.fromARGB(255, 68, 45, 45),
                    alignment: Alignment.center,
                    child: Text(carrierCode.isNotEmpty ? carrierCode : '?'),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            // info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$time · $date',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${carrierName.isNotEmpty ? carrierName : carrierCode} · ${flightNumber.isNotEmpty ? flightNumber : ''}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(stopsText, style: TextStyle(color: stops == 0 ? Colors.green : const Color.fromARGB(255, 117, 101, 77))),
                  const SizedBox(height: 6),
                  Text('Route: $from → $to', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            // price & actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(priceText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites')));
                  },
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _showFlightDetails(Map<String, dynamic> flight) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final carrierName = (flight['carrier'] ?? flight['carrierName'] ?? '').toString();
        final carrierCode = (flight['carrierCode'] ?? flight['carrier_code'] ?? '').toString();
        final flightNumber = (flight['flightNumber'] ?? flight['id'] ?? '').toString();
        final from = (flight['from'] ?? '').toString();
        final to = (flight['to'] ?? '').toString();
        final date = (flight['date'] ?? '').toString();
        final time = _extractTime(flight);
        final priceText = _formatPrice(flight['price']);
        final logo = (flight['carrierLogo'] ?? flight['logo'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            runSpacing: 12,
            children: [
              Row(children: [
                if (logo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(logo, width: 72, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                const SizedBox(width: 12),
                Text('$carrierName ${carrierCode.isNotEmpty ? '· $carrierCode' : ''}', style: Theme.of(context).textTheme.titleLarge),
              ]),
              Text('Flight: $flightNumber'),
              Text('Route: $from → $to'),
              Text('Date: $date  ·  Time: $time'),
              if (priceText != '—') Text('Price: $priceText'),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    await fetchFlights();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.multiCityQuery.isNotEmpty
        ? '${widget.multiCityQuery[0]['from'] ?? ''} → ${widget.multiCityQuery[0]['to'] ?? ''}'
        : 'Flight Results';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Failed to load flights.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(onPressed: fetchFlights, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    itemCount: flights.length,
                    itemBuilder: (c, i) => buildFlightCard(flights[i]),
                  ),
                ),
    );
  }
}
