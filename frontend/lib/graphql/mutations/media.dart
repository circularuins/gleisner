const getUploadUrlMutation = r'''
  mutation GetUploadUrl(
    $category: UploadCategory!,
    $contentType: String!,
    $contentLength: Int!
  ) {
    getUploadUrl(
      category: $category,
      contentType: $contentType,
      contentLength: $contentLength
    ) {
      uploadUrl
      publicUrl
      key
    }
  }
''';
