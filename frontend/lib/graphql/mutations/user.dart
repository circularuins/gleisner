const updateMeMutation = r'''
  mutation UpdateMe($displayName: String, $bio: String, $avatarUrl: String) {
    updateMe(displayName: $displayName, bio: $bio, avatarUrl: $avatarUrl) {
      id
      displayName
      bio
      avatarUrl
      updatedAt
    }
  }
''';
