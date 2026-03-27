const updateMeMutation = r'''
  mutation UpdateMe($displayName: String, $bio: String, $avatarUrl: String, $profileVisibility: String) {
    updateMe(displayName: $displayName, bio: $bio, avatarUrl: $avatarUrl, profileVisibility: $profileVisibility) {
      id
      displayName
      bio
      avatarUrl
      profileVisibility
      updatedAt
    }
  }
''';
