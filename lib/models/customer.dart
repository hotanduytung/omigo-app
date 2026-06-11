class Customer {
  final String name;
  final String phoneNumber;

  Customer({
    required this.name,
    required this.phoneNumber,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }
}
