const postFields = '''
  id
  mediaType
  title
  body
  bodyFormat
  mediaUrl
  thumbnailUrl
  duration
  eventAt
  importance
  visibility
  layoutX
  layoutY
  contentHash
  articleGenre
  externalPublish
  ogTitle
  ogDescription
  ogImage
  ogSiteName
  createdAt
  updatedAt
  author {
    id
    username
    displayName
    avatarUrl
  }
  track {
    id
    name
    color
  }
  reactionCounts {
    emoji
    count
  }
  myReactions
  outgoingConnections {
    id
    sourceId
    targetId
    connectionType
  }
  incomingConnections {
    id
    sourceId
    targetId
    connectionType
  }
  constellation {
    id
    name
    anchorPostId
  }
  media {
    id
    mediaUrl
    position
  }
''';

const postsQuery =
    '''
  query Posts(\$trackId: String!) {
    posts(trackId: \$trackId) {
      $postFields
    }
  }
''';

const myUnassignedPostsQuery =
    '''
  query {
    myUnassignedPosts {
      $postFields
    }
  }
''';

const postQuery =
    '''
  query Post(\$id: String!) {
    post(id: \$id) {
      $postFields
    }
  }
''';
