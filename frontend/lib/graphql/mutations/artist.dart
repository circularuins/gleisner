const registerArtistMutation = '''
  mutation RegisterArtist(\$artistUsername: String!, \$displayName: String!) {
    registerArtist(artistUsername: \$artistUsername, displayName: \$displayName) {
      id
      artistUsername
      displayName
    }
  }
''';
