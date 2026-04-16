import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gleisner'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @navTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @actingAsChild.
  ///
  /// In en, this message translates to:
  /// **'Acting as {childName}'**
  String actingAsChild(String childName);

  /// No description provided for @exitChildMode.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitChildMode;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get loginSubtitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signupSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'How you want to be known'**
  String get displayNameHint;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @birthYearMonth.
  ///
  /// In en, this message translates to:
  /// **'Birth Year & Month'**
  String get birthYearMonth;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your invite code'**
  String get inviteCodeHint;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccount;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmailFormat;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @usernameFormat.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, underscores (2-30 chars)'**
  String get usernameFormat;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} is required'**
  String fieldRequired(String fieldName);

  /// No description provided for @invalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code format'**
  String get invalidInviteCode;

  /// No description provided for @welcomeToGleisner.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Gleisner'**
  String get welcomeToGleisner;

  /// No description provided for @yourCreativeUniverseAwaits.
  ///
  /// In en, this message translates to:
  /// **'Your creative universe awaits'**
  String get yourCreativeUniverseAwaits;

  /// No description provided for @personalAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Account'**
  String get personalAccountTitle;

  /// No description provided for @personalAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Discover artists, follow tracks, build your timeline. This is your personal identity on Gleisner.'**
  String get personalAccountDesc;

  /// No description provided for @artistUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'+ Artist Upgrade'**
  String get artistUpgradeTitle;

  /// No description provided for @artistUpgradeDesc.
  ///
  /// In en, this message translates to:
  /// **'Create an Artist Page, set up tracks, and broadcast your work. You can upgrade anytime after signup.'**
  String get artistUpgradeDesc;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {displayName}!'**
  String welcomeUser(String displayName);

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Your personal account is ready.'**
  String get accountReady;

  /// No description provided for @featureTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get featureTimeline;

  /// No description provided for @featureDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover artists'**
  String get featureDiscover;

  /// No description provided for @featureTuneIn.
  ///
  /// In en, this message translates to:
  /// **'Tune In to artists'**
  String get featureTuneIn;

  /// No description provided for @readyToShare.
  ///
  /// In en, this message translates to:
  /// **'Ready to share your work?'**
  String get readyToShare;

  /// No description provided for @artistUpgradeExplain.
  ///
  /// In en, this message translates to:
  /// **'Your personal account stays — the artist profile is a separate creative identity.'**
  String get artistUpgradeExplain;

  /// No description provided for @becomeAnArtist.
  ///
  /// In en, this message translates to:
  /// **'Become an Artist'**
  String get becomeAnArtist;

  /// No description provided for @exploreGleisner.
  ///
  /// In en, this message translates to:
  /// **'Explore Gleisner'**
  String get exploreGleisner;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @joinedDate.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedDate(String date);

  /// No description provided for @tunedInCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Tuned In'**
  String tunedInCount(int count);

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} track} other{{count} tracks}}'**
  String trackCount(int count);

  /// No description provided for @artistRegistration.
  ///
  /// In en, this message translates to:
  /// **'Artist Registration'**
  String get artistRegistration;

  /// No description provided for @yourMusicYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your music, your story.'**
  String get yourMusicYourStory;

  /// No description provided for @returnToMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Return to My Account'**
  String get returnToMyAccount;

  /// No description provided for @switchToChild.
  ///
  /// In en, this message translates to:
  /// **'Switch to {childName}'**
  String switchToChild(String childName);

  /// No description provided for @childAccountName.
  ///
  /// In en, this message translates to:
  /// **'{childName}\'s Account'**
  String childAccountName(String childName);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @enterPasswordToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get enterPasswordToConfirm;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Check your password.'**
  String get deleteAccountFailed;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @tapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get tapToChange;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @profileVisibility.
  ///
  /// In en, this message translates to:
  /// **'Profile Visibility'**
  String get profileVisibility;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @privateLocked.
  ///
  /// In en, this message translates to:
  /// **'Private (locked)'**
  String get privateLocked;

  /// No description provided for @artistVisibilityPrivateDesc.
  ///
  /// In en, this message translates to:
  /// **'Your artist page is hidden from Discover and search. Only existing fans and direct links can access it.'**
  String get artistVisibilityPrivateDesc;

  /// No description provided for @artistVisibilityPublicDesc.
  ///
  /// In en, this message translates to:
  /// **'Your artist page is visible in Discover and search. Anyone can view your profile and Tune In.'**
  String get artistVisibilityPublicDesc;

  /// No description provided for @viewArtistPage.
  ///
  /// In en, this message translates to:
  /// **'View Artist Page'**
  String get viewArtistPage;

  /// No description provided for @addChildAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Child Account'**
  String get addChildAccount;

  /// No description provided for @aboutChildAccounts.
  ///
  /// In en, this message translates to:
  /// **'About Child Accounts'**
  String get aboutChildAccounts;

  /// No description provided for @manageChildPresence.
  ///
  /// In en, this message translates to:
  /// **'Manage your child\'s creative presence'**
  String get manageChildPresence;

  /// No description provided for @childAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'A child account lets your child build their creative journey under your supervision.\n\n• You can switch between your account and your child\'s at any time from your Profile\n• Your child can register as an artist and create posts\n• Their user profile stays private by default\n• You control whether their artist page is public or private'**
  String get childAccountDescription;

  /// No description provided for @childAccountPrivateNote.
  ///
  /// In en, this message translates to:
  /// **'Child accounts have private profiles by default and cannot be changed.'**
  String get childAccountPrivateNote;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// No description provided for @passwordsMustMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match'**
  String get passwordsMustMatch;

  /// No description provided for @invalidPasswordMinimum.
  ///
  /// In en, this message translates to:
  /// **'Invalid password. Minimum 8 characters.'**
  String get invalidPasswordMinimum;

  /// No description provided for @yourCreativeJourney.
  ///
  /// In en, this message translates to:
  /// **'Your Creative Journey'**
  String get yourCreativeJourney;

  /// No description provided for @wizardStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4'**
  String wizardStepOf(int step);

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learnMore;

  /// No description provided for @createArtistProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Your Artist Profile'**
  String get createArtistProfile;

  /// No description provided for @artistUsername.
  ///
  /// In en, this message translates to:
  /// **'Artist Username'**
  String get artistUsername;

  /// No description provided for @chooseUniqueHandle.
  ///
  /// In en, this message translates to:
  /// **'Choose your unique handle'**
  String get chooseUniqueHandle;

  /// No description provided for @yourProfessionalName.
  ///
  /// In en, this message translates to:
  /// **'Your professional name'**
  String get yourProfessionalName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get tagline;

  /// No description provided for @oneLiners.
  ///
  /// In en, this message translates to:
  /// **'One-liner about your work'**
  String get oneLiners;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @whereYouCreate.
  ///
  /// In en, this message translates to:
  /// **'Where you create'**
  String get whereYouCreate;

  /// No description provided for @activeSinceYear.
  ///
  /// In en, this message translates to:
  /// **'Active Since (year)'**
  String get activeSinceYear;

  /// No description provided for @yearYouStarted.
  ///
  /// In en, this message translates to:
  /// **'Year you started'**
  String get yearYouStarted;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @createOwnGenre.
  ///
  /// In en, this message translates to:
  /// **'Create your own genre...'**
  String get createOwnGenre;

  /// No description provided for @selectTracksProfile.
  ///
  /// In en, this message translates to:
  /// **'Select Tracks for Your Profile'**
  String get selectTracksProfile;

  /// No description provided for @musicianTemplate.
  ///
  /// In en, this message translates to:
  /// **'Musician'**
  String get musicianTemplate;

  /// No description provided for @visualArtistTemplate.
  ///
  /// In en, this message translates to:
  /// **'Visual Artist'**
  String get visualArtistTemplate;

  /// No description provided for @writerTemplate.
  ///
  /// In en, this message translates to:
  /// **'Writer'**
  String get writerTemplate;

  /// No description provided for @filmmakerTemplate.
  ///
  /// In en, this message translates to:
  /// **'Filmmaker'**
  String get filmmakerTemplate;

  /// No description provided for @youreAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get youreAllSet;

  /// No description provided for @artistProfileLive.
  ///
  /// In en, this message translates to:
  /// **'Your artist profile is live.'**
  String get artistProfileLive;

  /// No description provided for @viewYourTimeline.
  ///
  /// In en, this message translates to:
  /// **'View Your Timeline'**
  String get viewYourTimeline;

  /// No description provided for @startSharingPosts.
  ///
  /// In en, this message translates to:
  /// **'Start Sharing Posts'**
  String get startSharingPosts;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get skipForNow;

  /// No description provided for @startSharingCreativeJourney.
  ///
  /// In en, this message translates to:
  /// **'Start sharing your creative journey'**
  String get startSharingCreativeJourney;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPost;

  /// No description provided for @selectTrack.
  ///
  /// In en, this message translates to:
  /// **'Select a Track'**
  String get selectTrack;

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content Type'**
  String get contentType;

  /// No description provided for @mediaTypeThought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get mediaTypeThought;

  /// No description provided for @mediaTypeArticle.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get mediaTypeArticle;

  /// No description provided for @mediaTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mediaTypeImage;

  /// No description provided for @mediaTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaTypeVideo;

  /// No description provided for @mediaTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaTypeAudio;

  /// No description provided for @mediaTypeLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get mediaTypeLink;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get body;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connections;

  /// No description provided for @importance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get importance;

  /// No description provided for @importanceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get importanceLow;

  /// No description provided for @importanceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get importanceMedium;

  /// No description provided for @importanceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get importanceHigh;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @newTrack.
  ///
  /// In en, this message translates to:
  /// **'New Track'**
  String get newTrack;

  /// No description provided for @trackName.
  ///
  /// In en, this message translates to:
  /// **'Track Name'**
  String get trackName;

  /// No description provided for @maxTracks.
  ///
  /// In en, this message translates to:
  /// **'Maximum {max} tracks'**
  String maxTracks(int max);

  /// No description provided for @createTrackFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a track first'**
  String get createTrackFirst;

  /// No description provided for @maxCharacters.
  ///
  /// In en, this message translates to:
  /// **'Maximum {max} characters'**
  String maxCharacters(int max);

  /// No description provided for @whatsOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get whatsOnYourMind;

  /// No description provided for @writeCaption.
  ///
  /// In en, this message translates to:
  /// **'Write a caption...'**
  String get writeCaption;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get addNote;

  /// No description provided for @titleAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Title (auto-filled from link if empty)'**
  String get titleAutoFilled;

  /// No description provided for @urlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'https://'**
  String get urlPlaceholder;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add Link'**
  String get addLink;

  /// No description provided for @addConstellation.
  ///
  /// In en, this message translates to:
  /// **'Add Constellation'**
  String get addConstellation;

  /// No description provided for @eventDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Event date (optional)'**
  String get eventDateOptional;

  /// No description provided for @uploadImageBeforePosting.
  ///
  /// In en, this message translates to:
  /// **'Please upload at least one image before posting'**
  String get uploadImageBeforePosting;

  /// No description provided for @uploadFileBeforePosting.
  ///
  /// In en, this message translates to:
  /// **'Please upload a file before posting'**
  String get uploadFileBeforePosting;

  /// No description provided for @textRequired.
  ///
  /// In en, this message translates to:
  /// **'Text is required'**
  String get textRequired;

  /// No description provided for @imageRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one image is required'**
  String get imageRequired;

  /// No description provided for @mediaFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Media file is required for this post type'**
  String get mediaFileRequired;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPost;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get deletePostConfirm;

  /// No description provided for @tunedIn.
  ///
  /// In en, this message translates to:
  /// **'Tuned In'**
  String get tunedIn;

  /// No description provided for @tuneIn.
  ///
  /// In en, this message translates to:
  /// **'Tune In'**
  String get tuneIn;

  /// No description provided for @discoverMoreArtists.
  ///
  /// In en, this message translates to:
  /// **'Discover More Artists'**
  String get discoverMoreArtists;

  /// No description provided for @constellationPostCount.
  ///
  /// In en, this message translates to:
  /// **'Constellation · {count} posts'**
  String constellationPostCount(int count);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @joinCreativeUniverse.
  ///
  /// In en, this message translates to:
  /// **'Join the creative universe'**
  String get joinCreativeUniverse;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Search artists...'**
  String get searchArtists;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No artists found'**
  String get noArtistsFound;

  /// No description provided for @failedToLoadArtists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artists. Please try again.'**
  String get failedToLoadArtists;

  /// No description provided for @removeConstellationName.
  ///
  /// In en, this message translates to:
  /// **'Remove constellation name?'**
  String get removeConstellationName;

  /// No description provided for @failedRemoveConstellation.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove constellation. Please try again.'**
  String get failedRemoveConstellation;

  /// No description provided for @failedDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post. Please try again.'**
  String get failedDeletePost;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @linkPost.
  ///
  /// In en, this message translates to:
  /// **'Link Post'**
  String get linkPost;

  /// No description provided for @viewPostExternal.
  ///
  /// In en, this message translates to:
  /// **'View post on external site'**
  String get viewPostExternal;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @addReaction.
  ///
  /// In en, this message translates to:
  /// **'Add Reaction'**
  String get addReaction;

  /// No description provided for @constellation.
  ///
  /// In en, this message translates to:
  /// **'Constellation'**
  String get constellation;

  /// No description provided for @nameConstellation.
  ///
  /// In en, this message translates to:
  /// **'Name This Constellation'**
  String get nameConstellation;

  /// No description provided for @editPostTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPostTooltip;

  /// No description provided for @deletePostTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePostTooltip;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutGleisner.
  ///
  /// In en, this message translates to:
  /// **'About Gleisner'**
  String get aboutGleisner;

  /// No description provided for @gleisnerLogoLabel.
  ///
  /// In en, this message translates to:
  /// **'Gleisner logo'**
  String get gleisnerLogoLabel;

  /// No description provided for @aboutOperatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get aboutOperatorTitle;

  /// No description provided for @aboutOperatorBody.
  ///
  /// In en, this message translates to:
  /// **'This service is operated as a personal project.\nContact: gleisner.app@gmail.com'**
  String get aboutOperatorBody;

  /// No description provided for @aboutExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'External Services (Third-party data transmission)'**
  String get aboutExternalTitle;

  /// No description provided for @aboutExternalBody.
  ///
  /// In en, this message translates to:
  /// **'Gleisner uses the following external services. Your data may be transmitted to these services in the course of normal operation:\n\n1. Cloudflare (CDN, media storage)\n   - Purpose: Content delivery, image/video hosting\n   - Data: Page requests, uploaded media\n\n2. Claude API (Anthropic)\n   - Purpose: AI-assisted title generation\n   - Data: Post content (title/body) for processing\n\n3. Railway\n   - Purpose: Application hosting, database\n   - Data: All application data is stored on Railway servers'**
  String get aboutExternalBody;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Gleisner is a platform for artists to share their multifaceted creative activities through a DAW-style multi-track timeline.\n\nNamed after the Gleisner robots in Greg Egan\'s \"Diaspora\" — bridging the physical and digital worlds.'**
  String get aboutDescription;

  /// No description provided for @recentPosts.
  ///
  /// In en, this message translates to:
  /// **'Recent Posts'**
  String get recentPosts;

  /// No description provided for @viewFullTimeline.
  ///
  /// In en, this message translates to:
  /// **'View full timeline'**
  String get viewFullTimeline;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @editCover.
  ///
  /// In en, this message translates to:
  /// **'Edit Cover'**
  String get editCover;

  /// No description provided for @editAbout.
  ///
  /// In en, this message translates to:
  /// **'Edit About'**
  String get editAbout;

  /// No description provided for @yearMustBe4Digits.
  ///
  /// In en, this message translates to:
  /// **'Year must be 4 digits'**
  String get yearMustBe4Digits;

  /// No description provided for @editGenres.
  ///
  /// In en, this message translates to:
  /// **'Edit Genres'**
  String get editGenres;

  /// No description provided for @genresSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/5 selected'**
  String genresSelectedCount(int count);

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get current;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get available;

  /// No description provided for @manageTracks.
  ///
  /// In en, this message translates to:
  /// **'Manage Tracks'**
  String get manageTracks;

  /// No description provided for @tracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/10 tracks'**
  String tracksCount(int count);

  /// No description provided for @noTracksYet.
  ///
  /// In en, this message translates to:
  /// **'No tracks yet. Tap + to add one.'**
  String get noTracksYet;

  /// No description provided for @deleteTrackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {trackName}?'**
  String deleteTrackConfirm(String trackName);

  /// No description provided for @manageLinks.
  ///
  /// In en, this message translates to:
  /// **'Manage Links'**
  String get manageLinks;

  /// No description provided for @noLinksYet.
  ///
  /// In en, this message translates to:
  /// **'No links yet. Tap + to add one.'**
  String get noLinksYet;

  /// No description provided for @linkCategoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get linkCategoryMusic;

  /// No description provided for @linkCategorySocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get linkCategorySocial;

  /// No description provided for @linkCategoryVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get linkCategoryVideo;

  /// No description provided for @linkCategoryWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get linkCategoryWebsite;

  /// No description provided for @linkCategoryStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get linkCategoryStore;

  /// No description provided for @linkCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get linkCategoryOther;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get invalidUrl;

  /// No description provided for @milestoneCategoryAward.
  ///
  /// In en, this message translates to:
  /// **'Award'**
  String get milestoneCategoryAward;

  /// No description provided for @milestoneCategoryRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get milestoneCategoryRelease;

  /// No description provided for @milestoneCategoryEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get milestoneCategoryEvent;

  /// No description provided for @milestoneCategoryAffiliation.
  ///
  /// In en, this message translates to:
  /// **'Affiliation'**
  String get milestoneCategoryAffiliation;

  /// No description provided for @milestoneCategoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get milestoneCategoryEducation;

  /// No description provided for @milestoneCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get milestoneCategoryOther;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteConfirmation;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @editMilestone.
  ///
  /// In en, this message translates to:
  /// **'Edit Milestone'**
  String get editMilestone;

  /// No description provided for @milestonesCountOf.
  ///
  /// In en, this message translates to:
  /// **'{count}/200'**
  String milestonesCountOf(int count);

  /// No description provided for @unassignedPosts.
  ///
  /// In en, this message translates to:
  /// **'Unassigned Posts'**
  String get unassignedPosts;

  /// No description provided for @noUnassignedPosts.
  ///
  /// In en, this message translates to:
  /// **'No unassigned posts'**
  String get noUnassignedPosts;

  /// No description provided for @assignToTrack.
  ///
  /// In en, this message translates to:
  /// **'Assign to Track'**
  String get assignToTrack;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @failedAssignPost.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign post. Please try again.'**
  String get failedAssignPost;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @artistHasntArrivedYet.
  ///
  /// In en, this message translates to:
  /// **'This artist hasn\'t arrived yet'**
  String get artistHasntArrivedYet;

  /// No description provided for @starsStillAligning.
  ///
  /// In en, this message translates to:
  /// **'The stars are still aligning for this one.'**
  String get starsStillAligning;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @yourCreativeUniverse.
  ///
  /// In en, this message translates to:
  /// **'Your creative universe'**
  String get yourCreativeUniverse;

  /// No description provided for @ownCreativeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Own your creative identity'**
  String get ownCreativeIdentity;

  /// No description provided for @keepArtKeepControl.
  ///
  /// In en, this message translates to:
  /// **'Keep your art, keep control'**
  String get keepArtKeepControl;

  /// No description provided for @mapYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Map your journey across infinite tracks'**
  String get mapYourJourney;

  /// No description provided for @multipleProjectsOnePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiple creative projects in one place'**
  String get multipleProjectsOnePlaceTitle;

  /// No description provided for @watchConnectionsEmerge.
  ///
  /// In en, this message translates to:
  /// **'Watch connections emerge between ideas'**
  String get watchConnectionsEmerge;

  /// No description provided for @seeHowIdeasRelate.
  ///
  /// In en, this message translates to:
  /// **'See how your ideas relate and evolve'**
  String get seeHowIdeasRelate;

  /// No description provided for @tryItFirst.
  ///
  /// In en, this message translates to:
  /// **'Try it first'**
  String get tryItFirst;

  /// No description provided for @noAccountNeeded.
  ///
  /// In en, this message translates to:
  /// **'No account needed'**
  String get noAccountNeeded;

  /// No description provided for @formatting.
  ///
  /// In en, this message translates to:
  /// **'Formatting'**
  String get formatting;

  /// No description provided for @hideFormatting.
  ///
  /// In en, this message translates to:
  /// **'Hide formatting'**
  String get hideFormatting;

  /// No description provided for @insertImage.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get insertImage;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @bulletList.
  ///
  /// In en, this message translates to:
  /// **'Bullet list'**
  String get bulletList;

  /// No description provided for @trackAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Track \"{name}\" already exists'**
  String trackAlreadyExists(String name);

  /// No description provided for @failedCreateTrack.
  ///
  /// In en, this message translates to:
  /// **'Failed to create track'**
  String get failedCreateTrack;

  /// No description provided for @colorAutoAssigned.
  ///
  /// In en, this message translates to:
  /// **'Color: auto-assigned'**
  String get colorAutoAssigned;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @audioUploaded.
  ///
  /// In en, this message translates to:
  /// **'Audio uploaded'**
  String get audioUploaded;

  /// No description provided for @linkToExistingPost.
  ///
  /// In en, this message translates to:
  /// **'Link to existing post'**
  String get linkToExistingPost;

  /// No description provided for @addAnotherConnection.
  ///
  /// In en, this message translates to:
  /// **'Add another connection'**
  String get addAnotherConnection;

  /// No description provided for @publishExternally.
  ///
  /// In en, this message translates to:
  /// **'Publish externally'**
  String get publishExternally;

  /// No description provided for @publishExternallyDescription.
  ///
  /// In en, this message translates to:
  /// **'Make available on the public article site'**
  String get publishExternallyDescription;

  /// No description provided for @linking.
  ///
  /// In en, this message translates to:
  /// **'Linking...'**
  String get linking;

  /// No description provided for @failedUpdatePost.
  ///
  /// In en, this message translates to:
  /// **'Failed to update post. Please try again.'**
  String get failedUpdatePost;

  /// No description provided for @removeConstellationDescription.
  ///
  /// In en, this message translates to:
  /// **'The posts will remain but the constellation grouping will be removed.'**
  String get removeConstellationDescription;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @quietNote.
  ///
  /// In en, this message translates to:
  /// **'quiet note'**
  String get quietNote;

  /// No description provided for @heroMoment.
  ///
  /// In en, this message translates to:
  /// **'hero moment'**
  String get heroMoment;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
