const registerArtistMutation = '''
  mutation RegisterArtist(
    \$artistUsername: String!,
    \$displayName: String!,
    \$tagline: String,
    \$location: String,
    \$activeSince: Int
  ) {
    registerArtist(
      artistUsername: \$artistUsername,
      displayName: \$displayName,
      tagline: \$tagline,
      location: \$location,
      activeSince: \$activeSince
    ) {
      id
      artistUsername
      displayName
      tagline
      location
      activeSince
    }
  }
''';
