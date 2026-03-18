class TrustedContact {
  final int? id;
  final String name;
  final String phone;
  final String relation;
  final int priority; // 1 = first called, 2 = second, 3 = third

  const TrustedContact({
    this.id,
    required this.name,
    required this.phone,
    this.relation = '',
    this.priority = 1,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'priority': priority,
      };

  factory TrustedContact.fromMap(Map<String, dynamic> map) => TrustedContact(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String,
        relation: map['relation'] as String? ?? '',
        priority: map['priority'] as int? ?? 1,
      );

  TrustedContact copyWith({String? name, String? phone, String? relation, int? priority}) =>
      TrustedContact(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        priority: priority ?? this.priority,
      );
}
