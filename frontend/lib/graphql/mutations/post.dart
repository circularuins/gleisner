import '../queries/post.dart';

const createPostMutation =
    '''
  mutation CreatePost(
    \$trackId: String!,
    \$mediaType: MediaType!,
    \$title: String,
    \$body: String,
    \$mediaUrl: String,
    \$thumbnailUrl: String,
    \$importance: Float,
    \$visibility: String
  ) {
    createPost(
      trackId: \$trackId,
      mediaType: \$mediaType,
      title: \$title,
      body: \$body,
      mediaUrl: \$mediaUrl,
      thumbnailUrl: \$thumbnailUrl,
      importance: \$importance,
      visibility: \$visibility
    ) {
      $postFields
    }
  }
''';

const updatePostMutation =
    '''
  mutation UpdatePost(
    \$id: String!,
    \$trackId: String,
    \$title: String,
    \$body: String,
    \$mediaUrl: String,
    \$thumbnailUrl: String,
    \$importance: Float,
    \$visibility: String
  ) {
    updatePost(
      id: \$id,
      trackId: \$trackId,
      title: \$title,
      body: \$body,
      mediaUrl: \$mediaUrl,
      thumbnailUrl: \$thumbnailUrl,
      importance: \$importance,
      visibility: \$visibility
    ) {
      $postFields
    }
  }
''';
