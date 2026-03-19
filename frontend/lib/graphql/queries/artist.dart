const artistQuery = r'''
  query Artist($username: String!) {
    artist(username: $username) {
      id
      artistUsername
      displayName
      bio
      tagline
      avatarUrl
      coverImageUrl
      tunedInCount
      tracks {
        id
        name
        color
        createdAt
      }
    }
  }
''';
