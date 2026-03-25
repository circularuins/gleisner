const toggleTuneInMutation = r'''
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) {
      createdAt
      artist {
        id
        artistUsername
        displayName
        avatarUrl
        tunedInCount
      }
    }
  }
''';
