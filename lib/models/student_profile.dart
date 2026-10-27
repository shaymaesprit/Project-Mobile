class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.university,
    required this.level,
    required this.specialty,
    this.phone,
    this.photoUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String university;
  final String level;
  final String specialty;
  final String? phone;
  final String? photoUrl;

  String get displayName => '$firstName $lastName'.trim();

  factory StudentProfile.fromJson(Map<String, dynamic> json) =>
      StudentProfile(
        id: json['id'] as String,
        firstName: json['prenom'] as String? ?? '',
        lastName: json['nom'] as String? ?? '',
        email: json['email'] as String? ?? '',
        university: json['universite'] as String? ?? '',
        level: json['niveau'] as String? ?? '',
        specialty: json['specialite'] as String? ?? '',
        phone: json['telephone'] as String?,
        photoUrl: json['photo_url'] as String?,
      );
}
