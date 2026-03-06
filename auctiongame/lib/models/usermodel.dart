class User {
  int? id;
  int? phone;
  String? name;
  String? email;
  int? points;
  bool? isActive;
  String? dob;
  bool? profilecompleted;
  String? profilepic;

  User({
    this.id,
    this.phone,
    this.name,
    this.email,
    this.points,
    this.isActive,
    this.dob,
    this.profilecompleted,
    this.profilepic,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    phone = json['phone'];
    name = json['name'];
    email = json['email'];
    points = json['points'];
    isActive = json['isActive'];
    dob = json['dob'];
    profilepic = json['profilepic'];
    profilecompleted = json['profilecompleted'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['phone'] = this.phone;
    data['name'] = this.name;
    data['email'] = this.email;
    data['points'] = this.points;
    data['isActive'] = this.isActive;
    data['dob'] = this.dob;
    data['profilecompleted'] = this.profilecompleted;
    data['profilepic'] = this.profilepic;
    return data;
  }
}
