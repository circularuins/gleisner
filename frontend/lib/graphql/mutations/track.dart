const createTrackMutation = '''
  mutation CreateTrack(\$name: String!, \$color: String!) {
    createTrack(name: \$name, color: \$color) {
      id
      name
      color
      createdAt
    }
  }
''';

const deleteTrackMutation = r'''
  mutation DeleteTrack($id: String!) {
    deleteTrack(id: $id) {
      id
      name
    }
  }
''';
