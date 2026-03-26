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

const updateArtistMutation = r'''
  mutation UpdateArtist(
    $displayName: String,
    $bio: String,
    $tagline: String,
    $location: String,
    $activeSince: Int,
    $avatarUrl: String,
    $coverImageUrl: String
  ) {
    updateArtist(
      displayName: $displayName,
      bio: $bio,
      tagline: $tagline,
      location: $location,
      activeSince: $activeSince,
      avatarUrl: $avatarUrl,
      coverImageUrl: $coverImageUrl
    ) {
      id
      artistUsername
      displayName
      bio
      tagline
      location
      activeSince
      avatarUrl
      coverImageUrl
      tunedInCount
    }
  }
''';

const createArtistLinkMutation = r'''
  mutation CreateArtistLink(
    $linkCategory: LinkCategory!,
    $platform: String!,
    $url: String!,
    $position: Int
  ) {
    createArtistLink(
      linkCategory: $linkCategory,
      platform: $platform,
      url: $url,
      position: $position
    ) {
      id
      linkCategory
      platform
      url
      position
    }
  }
''';

const updateArtistLinkMutation = r'''
  mutation UpdateArtistLink(
    $id: String!,
    $linkCategory: LinkCategory,
    $platform: String,
    $url: String,
    $position: Int
  ) {
    updateArtistLink(
      id: $id,
      linkCategory: $linkCategory,
      platform: $platform,
      url: $url,
      position: $position
    ) {
      id
      linkCategory
      platform
      url
      position
    }
  }
''';

const deleteArtistLinkMutation = r'''
  mutation DeleteArtistLink($id: String!) {
    deleteArtistLink(id: $id) {
      id
    }
  }
''';
