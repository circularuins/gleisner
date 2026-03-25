class Genre {
  final String id;
  final String name;
  final bool isPromoted;

  const Genre({required this.id, required this.name, this.isPromoted = false});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as String,
      name: json['name'] as String,
      isPromoted: json['isPromoted'] as bool? ?? false,
    );
  }
}

class ArtistGenre {
  final int position;
  final Genre genre;

  const ArtistGenre({required this.position, required this.genre});

  factory ArtistGenre.fromJson(Map<String, dynamic> json) {
    return ArtistGenre(
      position: json['position'] as int,
      genre: Genre.fromJson(json['genre'] as Map<String, dynamic>),
    );
  }
}
