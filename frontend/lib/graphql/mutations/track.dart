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

/// Both `$name` and `$color` are optional on the server side
/// (`backend/src/graphql/types/track.ts:101-102`). Omitting a variable
/// from the client request leaves the corresponding column unchanged;
/// sending it overwrites the column. Track.color is `varchar(7) NOT NULL`
/// and Track.name is `varchar(30) NOT NULL`, so neither value should be
/// sent as `null` (the server validates `name.length` / `HEX_COLOR_RE`
/// when the field is provided).
const updateTrackMutation = r'''
  mutation UpdateTrack($id: String!, $name: String, $color: String) {
    updateTrack(id: $id, name: $name, color: $color) {
      id
      name
      color
      createdAt
    }
  }
''';
