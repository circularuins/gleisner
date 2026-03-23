const nameConstellationMutation = '''
  mutation NameConstellation(\$postId: String!, \$name: String!) {
    nameConstellation(postId: \$postId, name: \$name) {
      id
      name
      anchorPostId
    }
  }
''';

const renameConstellationMutation = '''
  mutation RenameConstellation(\$id: String!, \$name: String!) {
    renameConstellation(id: \$id, name: \$name) {
      id
      name
      anchorPostId
    }
  }
''';
