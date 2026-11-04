class HospitalModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final List<String> services;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    List<String>? services,
  }) : services = services ?? const [];

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      services: List<String>.from(json['services'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'services': services,
    };
  }
}
