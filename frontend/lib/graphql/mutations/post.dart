import '../queries/post.dart';

const createPostMutation =
    '''
  mutation CreatePost(
    \$trackId: String!,
    \$mediaType: MediaType!,
    \$title: String,
    \$body: String,
    \$mediaUrl: String,
    \$importance: Float
  ) {
    createPost(
      trackId: \$trackId,
      mediaType: \$mediaType,
      title: \$title,
      body: \$body,
      mediaUrl: \$mediaUrl,
      importance: \$importance
    ) {
      $postFields
    }
  }
''';
