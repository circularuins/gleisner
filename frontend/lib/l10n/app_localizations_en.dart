// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gleisner';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get remove => 'Remove';

  @override
  String get register => 'Register';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navProfile => 'Profile';

  @override
  String actingAsChild(String childName) {
    return 'Acting as $childName';
  }

  @override
  String get exitChildMode => 'Exit';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign up';

  @override
  String get login => 'Login';

  @override
  String get loginSubtitle => 'Sign in to your account';

  @override
  String get signupSubtitle => 'Create your account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get displayName => 'Display Name';

  @override
  String get displayNameHint => 'How you want to be known';

  @override
  String get username => 'Username';

  @override
  String get birthYearMonth => 'Birth Year & Month';

  @override
  String get year => 'Year';

  @override
  String get month => 'Month';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get inviteCodeHint => 'Enter your invite code';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get usernameFormat => 'Letters, numbers, underscores (2-30 chars)';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'At least 8 characters';

  @override
  String fieldRequired(String fieldName) {
    return '$fieldName is required';
  }

  @override
  String get invalidInviteCode => 'Invalid invite code format';

  @override
  String get welcomeToGleisner => 'Welcome to Gleisner';

  @override
  String get yourCreativeUniverseAwaits => 'Your creative universe awaits';

  @override
  String get personalAccountTitle => 'Personal Account';

  @override
  String get personalAccountDesc =>
      'Discover artists, follow tracks, build your timeline. This is your personal identity on Gleisner.';

  @override
  String get artistUpgradeTitle => '+ Artist Upgrade';

  @override
  String get artistUpgradeDesc =>
      'Create an Artist Page, set up tracks, and broadcast your work. You can upgrade anytime after signup.';

  @override
  String get getStarted => 'Get Started';

  @override
  String welcomeUser(String displayName) {
    return 'Welcome, $displayName!';
  }

  @override
  String get accountReady => 'Your personal account is ready.';

  @override
  String get featureTimeline => 'Timeline';

  @override
  String get featureDiscover => 'Discover artists';

  @override
  String get featureTuneIn => 'Tune In to artists';

  @override
  String get readyToShare => 'Ready to share your work?';

  @override
  String get artistUpgradeExplain =>
      'Your personal account stays — the artist profile is a separate creative identity.';

  @override
  String get becomeAnArtist => 'Become an Artist';

  @override
  String get exploreGleisner => 'Explore Gleisner';

  @override
  String get profile => 'Profile';

  @override
  String joinedDate(String date) {
    return 'Joined $date';
  }

  @override
  String tunedInCount(int count) {
    return '$count Tuned In';
  }

  @override
  String get artist => 'Artist';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '$count track',
    );
    return '$_temp0';
  }

  @override
  String get artistRegistration => 'Artist Registration';

  @override
  String get yourMusicYourStory => 'Your music, your story.';

  @override
  String get returnToMyAccount => 'Return to My Account';

  @override
  String switchToChild(String childName) {
    return 'Switch to $childName';
  }

  @override
  String childAccountName(String childName) {
    return '$childName\'s Account';
  }

  @override
  String get logout => 'Logout';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get deleteAccountConfirmTitle => 'Delete this account?';

  @override
  String get cannotBeUndone => 'This action cannot be undone.';

  @override
  String get enterPasswordToConfirm => 'Enter your password to confirm';

  @override
  String get deleteAccountFailed =>
      'Failed to delete account. Check your password.';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get tapToChange => 'Tap to change';

  @override
  String get bio => 'Bio';

  @override
  String get profileVisibility => 'Profile Visibility';

  @override
  String get public => 'Public';

  @override
  String get private => 'Private';

  @override
  String get privateLocked => 'Private (locked)';

  @override
  String get artistVisibilityPrivateDesc =>
      'Your artist page is hidden from Discover and search. Only existing fans and direct links can access it.';

  @override
  String get artistVisibilityPublicDesc =>
      'Your artist page is visible in Discover and search. Anyone can view your profile and Tune In.';

  @override
  String get viewArtistPage => 'View Artist Page';

  @override
  String get addChildAccount => 'Add Child Account';

  @override
  String get aboutChildAccounts => 'About Child Accounts';

  @override
  String get manageChildPresence => 'Manage your child\'s creative presence';

  @override
  String get childAccountDescription =>
      'A child account lets your child build their creative journey under your supervision.\n\n• You can switch between your account and your child\'s at any time from your Profile\n• Your child can register as an artist and create posts\n• Their user profile stays private by default\n• You control whether their artist page is public or private';

  @override
  String get childAccountPrivateNote =>
      'Child accounts have private profiles by default and cannot be changed.';

  @override
  String get firstName => 'First Name';

  @override
  String get birthDate => 'Birth Date';

  @override
  String get passwordsMustMatch => 'Passwords must match';

  @override
  String get invalidPasswordMinimum =>
      'Invalid password. Minimum 8 characters.';

  @override
  String get yourCreativeJourney => 'Your Creative Journey';

  @override
  String wizardStepOf(int step) {
    return 'Step $step of 4';
  }

  @override
  String get learnMore => 'Learn More';

  @override
  String get createArtistProfile => 'Create Your Artist Profile';

  @override
  String get artistUsername => 'Artist Username';

  @override
  String get chooseUniqueHandle => 'Choose your unique handle';

  @override
  String get yourProfessionalName => 'Your professional name';

  @override
  String get tagline => 'Tagline';

  @override
  String get oneLiners => 'One-liner about your work';

  @override
  String get location => 'Location';

  @override
  String get whereYouCreate => 'Where you create';

  @override
  String get activeSinceYear => 'Active Since (year)';

  @override
  String get yearYouStarted => 'Year you started';

  @override
  String get genre => 'Genre';

  @override
  String get genres => 'Genres';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get createOwnGenre => 'Create your own genre...';

  @override
  String get selectTracksProfile => 'Select Tracks for Your Profile';

  @override
  String get musicianTemplate => 'Musician';

  @override
  String get visualArtistTemplate => 'Visual Artist';

  @override
  String get writerTemplate => 'Writer';

  @override
  String get filmmakerTemplate => 'Filmmaker';

  @override
  String get youreAllSet => 'You\'re All Set!';

  @override
  String get artistProfileLive => 'Your artist profile is live.';

  @override
  String get viewYourTimeline => 'View Your Timeline';

  @override
  String get startSharingPosts => 'Start Sharing Posts';

  @override
  String get skipForNow => 'Skip for Now';

  @override
  String get startSharingCreativeJourney =>
      'Start sharing your creative journey';

  @override
  String get newPost => 'New Post';

  @override
  String get selectTrack => 'Select a Track';

  @override
  String get contentType => 'Content Type';

  @override
  String get mediaTypeThought => 'Thought';

  @override
  String get mediaTypeArticle => 'Article';

  @override
  String get mediaTypeImage => 'Image';

  @override
  String get mediaTypeVideo => 'Video';

  @override
  String get mediaTypeAudio => 'Audio';

  @override
  String get mediaTypeLink => 'Link';

  @override
  String get title => 'Title';

  @override
  String get body => 'Body';

  @override
  String get visibility => 'Visibility';

  @override
  String get draft => 'Draft';

  @override
  String get connections => 'Connections';

  @override
  String get importance => 'Importance';

  @override
  String get importanceLow => 'Low';

  @override
  String get importanceMedium => 'Medium';

  @override
  String get importanceHigh => 'High';

  @override
  String get post => 'Post';

  @override
  String get newTrack => 'New Track';

  @override
  String get trackName => 'Track Name';

  @override
  String maxTracks(int max) {
    return 'Maximum $max tracks';
  }

  @override
  String get createTrackFirst => 'Create a track first';

  @override
  String maxCharacters(int max) {
    return 'Maximum $max characters';
  }

  @override
  String get whatsOnYourMind => 'What\'s on your mind?';

  @override
  String get writeCaption => 'Write a caption...';

  @override
  String get addNote => 'Add a note...';

  @override
  String get titleAutoFilled => 'Title (auto-filled from link if empty)';

  @override
  String get urlPlaceholder => 'https://';

  @override
  String get addLink => 'Add Link';

  @override
  String get addConstellation => 'Add Constellation';

  @override
  String get eventDateOptional => 'Event date (optional)';

  @override
  String get uploadImageBeforePosting =>
      'Please upload at least one image before posting';

  @override
  String get uploadFileBeforePosting => 'Please upload a file before posting';

  @override
  String get textRequired => 'Text is required';

  @override
  String get imageRequired => 'At least one image is required';

  @override
  String get mediaFileRequired => 'Media file is required for this post type';

  @override
  String get editPost => 'Edit Post';

  @override
  String get deletePostConfirm => 'Delete post?';

  @override
  String get tunedIn => 'Tuned In';

  @override
  String get tuneIn => 'Tune In';

  @override
  String get discoverMoreArtists => 'Discover More Artists';

  @override
  String constellationPostCount(int count) {
    return 'Constellation · $count posts';
  }

  @override
  String get all => 'All';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get joinCreativeUniverse => 'Join the creative universe';

  @override
  String get searchArtists => 'Search artists...';

  @override
  String get noArtistsFound => 'No artists found';

  @override
  String get failedToLoadArtists => 'Failed to load artists. Please try again.';

  @override
  String get removeConstellationName => 'Remove constellation name?';

  @override
  String get failedRemoveConstellation =>
      'Failed to remove constellation. Please try again.';

  @override
  String get failedDeletePost => 'Failed to delete post. Please try again.';

  @override
  String get comments => 'Comments';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get linkPost => 'Link Post';

  @override
  String get viewPostExternal => 'View post on external site';

  @override
  String get reactions => 'Reactions';

  @override
  String get addReaction => 'Add Reaction';

  @override
  String get constellation => 'Constellation';

  @override
  String get nameConstellation => 'Name This Constellation';

  @override
  String get editPostTooltip => 'Edit post';

  @override
  String get deletePostTooltip => 'Delete post';

  @override
  String get about => 'About';

  @override
  String get aboutGleisner => 'About Gleisner';

  @override
  String get gleisnerLogoLabel => 'Gleisner logo';

  @override
  String get aboutOperatorTitle => 'Operator';

  @override
  String get aboutOperatorBody =>
      'This service is operated as a personal project.\nContact: gleisner.app@gmail.com';

  @override
  String get aboutExternalTitle =>
      'External Services (Third-party data transmission)';

  @override
  String get aboutExternalBody =>
      'Gleisner uses the following external services. Your data may be transmitted to these services in the course of normal operation:\n\n1. Cloudflare (CDN, media storage)\n   - Purpose: Content delivery, image/video hosting\n   - Data: Page requests, uploaded media\n\n2. Claude API (Anthropic)\n   - Purpose: AI-assisted title generation\n   - Data: Post content (title/body) for processing\n\n3. Railway\n   - Purpose: Application hosting, database\n   - Data: All application data is stored on Railway servers';

  @override
  String get aboutDescription =>
      'Gleisner is a platform for artists to share their multifaceted creative activities through a DAW-style multi-track timeline.\n\nNamed after the Gleisner robots in Greg Egan\'s \"Diaspora\" — bridging the physical and digital worlds.';

  @override
  String get recentPosts => 'Recent Posts';

  @override
  String get viewFullTimeline => 'View full timeline';

  @override
  String get untitled => 'Untitled';

  @override
  String get editCover => 'Edit Cover';

  @override
  String get editAbout => 'Edit About';

  @override
  String get yearMustBe4Digits => 'Year must be 4 digits';

  @override
  String get editGenres => 'Edit Genres';

  @override
  String genresSelectedCount(int count) {
    return '$count/5 selected';
  }

  @override
  String get current => 'CURRENT';

  @override
  String get available => 'AVAILABLE';

  @override
  String get manageTracks => 'Manage Tracks';

  @override
  String tracksCount(int count) {
    return '$count/10 tracks';
  }

  @override
  String get noTracksYet => 'No tracks yet. Tap + to add one.';

  @override
  String deleteTrackConfirm(String trackName) {
    return 'Delete $trackName?';
  }

  @override
  String get manageLinks => 'Manage Links';

  @override
  String get noLinksYet => 'No links yet. Tap + to add one.';

  @override
  String get linkCategoryMusic => 'Music';

  @override
  String get linkCategorySocial => 'Social';

  @override
  String get linkCategoryVideo => 'Video';

  @override
  String get linkCategoryWebsite => 'Website';

  @override
  String get linkCategoryStore => 'Store';

  @override
  String get linkCategoryOther => 'Other';

  @override
  String get platform => 'Platform';

  @override
  String get url => 'URL';

  @override
  String get invalidUrl => 'Invalid URL';

  @override
  String get milestoneCategoryCareer => 'Career';

  @override
  String get milestoneCategoryAlbumRelease => 'Album Release';

  @override
  String get milestoneCategoryTour => 'Tour';

  @override
  String get milestoneCategoryAward => 'Award';

  @override
  String get milestoneCategoryCollaboration => 'Collaboration';

  @override
  String get milestoneCategoryPerformance => 'Performance';

  @override
  String get milestoneCategoryMilestone => 'Milestone';

  @override
  String get deleteConfirmation => 'Delete?';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get date => 'Date';

  @override
  String get editMilestone => 'Edit Milestone';

  @override
  String milestonesCountOf(int count) {
    return '$count/200';
  }

  @override
  String get unassignedPosts => 'Unassigned Posts';

  @override
  String get noUnassignedPosts => 'No unassigned posts';

  @override
  String get assignToTrack => 'Assign to Track';

  @override
  String get assign => 'Assign';

  @override
  String get failedAssignPost => 'Failed to assign post. Please try again.';

  @override
  String get discover => 'Discover';

  @override
  String get milestones => 'Milestones';

  @override
  String get links => 'Links';

  @override
  String get artistHasntArrivedYet => 'This artist hasn\'t arrived yet';

  @override
  String get starsStillAligning => 'The stars are still aligning for this one.';

  @override
  String get goBack => 'Go back';

  @override
  String get yourCreativeUniverse => 'Your creative universe';

  @override
  String get ownCreativeIdentity => 'Own your creative identity';

  @override
  String get keepArtKeepControl => 'Keep your art, keep control';

  @override
  String get mapYourJourney => 'Map your journey across infinite tracks';

  @override
  String get multipleProjectsOnePlaceTitle =>
      'Multiple creative projects in one place';

  @override
  String get watchConnectionsEmerge => 'Watch connections emerge between ideas';

  @override
  String get seeHowIdeasRelate => 'See how your ideas relate and evolve';

  @override
  String get tryItFirst => 'Try it first';

  @override
  String get noAccountNeeded => 'No account needed';

  @override
  String get formatting => 'Formatting';

  @override
  String get hideFormatting => 'Hide formatting';

  @override
  String get insertImage => 'Insert image';

  @override
  String get heading => 'Heading';

  @override
  String get bulletList => 'Bullet list';

  @override
  String trackAlreadyExists(String name) {
    return 'Track \"$name\" already exists';
  }

  @override
  String get failedCreateTrack => 'Failed to create track';

  @override
  String get colorAutoAssigned => 'Color: auto-assigned';

  @override
  String get replace => 'Replace';

  @override
  String get audioUploaded => 'Audio uploaded';

  @override
  String get linkToExistingPost => 'Link to existing post';

  @override
  String get addAnotherConnection => 'Add another connection';

  @override
  String get publishExternally => 'Publish externally';

  @override
  String get publishExternallyDescription =>
      'Make available on the public article site';

  @override
  String get linking => 'Linking...';

  @override
  String get failedUpdatePost => 'Failed to update post. Please try again.';

  @override
  String get removeConstellationDescription =>
      'The posts will remain but the constellation grouping will be removed.';

  @override
  String get view => 'View';

  @override
  String get quietNote => 'quiet note';

  @override
  String get heroMoment => 'hero moment';
}
