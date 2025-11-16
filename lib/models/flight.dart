class Flight {
  final String flightNumber;
  final String airline;
  final String departureTime;
  final String arrivalTime;
  final double? price;
  final String logoCode;

  Flight({
    required this.flightNumber,
    required this.airline,
    required this.departureTime,
    required this.arrivalTime,
    this.price,
    required this.logoCode,
  });

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      flightNumber: json['flightNumber'] ?? '',
      airline: json['airline'] ?? '',
      departureTime: json['departureTime'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      logoCode: json['logoCode'] ?? '',
    );
  }
}
