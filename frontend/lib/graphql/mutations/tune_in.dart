const toggleTuneInMutation = r'''
  mutation ToggleTuneIn($artistId: String!) {
    toggleTuneIn(artistId: $artistId) {
      createdAt
      lastPostActivityAt
      artist {
        id
        artistUsername
        displayName
        avatarUrl
        tunedInCount
        profileVisibility
      }
    }
  }
''';
