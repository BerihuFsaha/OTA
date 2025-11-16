import 'package:flutter/material.dart';
import '../models/flight.dart';

class FlightCard extends StatelessWidget {
  final Flight flight;

  const FlightCard({super.key, required this.flight});

  String _formatTime(String time) {
    // Expected format: HH:mm or HH:mm:ss
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Image.network(
              'https://content.airhex.com/content/logos/airlines_${flight.logoCode.toLowerCase()}_64_64.png',
              width: 64,
              height: 64,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.flight, size: 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flight.airline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Flight: ${flight.flightNumber}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.flight_takeoff, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Text('Departure: ${_formatTime(flight.departureTime)}'),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.flight_land, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Text('Arrival: ${_formatTime(flight.arrivalTime)}'),
                    ],
                  ),
                ],
              ),
            ),
            if (flight.price != null)
              Text('\$${flight.price!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
