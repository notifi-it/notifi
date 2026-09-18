import type { Plural } from './types.js';

function plural(one: string, other: string): Plural {
  return { one, other };
}

export const tagline = 'Push notifications for scripts, servers, apps and devices';

export const socials = {
  claims: [
    tagline,
    'One HTTP request to your iPhone or Mac',
    'Free, no signup',
    'Neither we nor Apple can read them',
  ],
  facebookAbout:
    'Push notifications to your iPhone or Mac from anything that can make an HTTP request. ' +
    'Encrypted with your public key, so neither we nor Apple can read them, and deleted from ' +
    'the server once delivered. No account. Free and open source, on the App Store for iOS 17+ ' +
    'and macOS 14+.',
};

export const copy = {
  api: {
    notFound: 'Not found.',
    unexpected: 'Unexpected error.',

    rateLimitedIP: 'Too many requests from this IP.',
    rateLimitedAccount: 'Rate limit exceeded. Too many notifications this hour.',
    uncollectedLimit:
      'Not sent. Too many uncollected notifications. Open the app to collect them.',

    badSignature: 'Invalid request signature.',
    staleTimestamp: 'Request timestamp is outside the allowed window.',

    unknownDevice: 'Device is not registered.',
    unknownKey: 'Unknown or revoked key.',
    keyNotFound: 'Key not found.',
    activeKeyLimit: 'Active key limit reached.',

    invalidDeviceBody: 'Invalid device registration body.',
    publicKeyMismatch: 'public_key must match the signing public key.',
    invalidEncryptionKey: 'encryption_public_key is not a valid P-256 point.',
    invalidCreateKeyBody: 'Invalid create-key body.',
    invalidUpdateKeyBody: 'Invalid update-key body.',
    invalidDeviceSettingsBody: 'Invalid device settings body.',
    invalidHistoryQuery: 'Invalid history query.',
    invalidSendParams: 'Invalid send parameters.',
    occurredAtTooFuture: 'occurred_at is too far in the future.',
    titleCropped:
      'Title shortened to {max} characters.',
    messageCropped:
      'Body shortened to {max} characters.',
    strictContentRejected:
      'Not sent. This device is set to refuse a notification it cannot deliver as written.',
    keyFailed: '{key}: {reason}',

  },

  store: {
    name: 'notifi: Push Notifications',
    subtitle: 'For scripts, servers and apps',
    promotionalText:
      'One HTTP request and it’s on your iPhone or Mac. Encrypted with your public key, so we can’t read it. No accounts.',
    keywords:
      'webhook,api,notify,alerts,self,hosted,cron,curl,cli,devops,homelab,ssh,docker,' +
      'terminal,developer',
    description:
      'Push notifications from anything that can make an HTTP request.\n' +
      '\n' +
      'Send notifi.it a title, and optionally a body, image or link, and it appears on your iPhone, iPad or Mac immediately.\n' +
      '\n' +
      'https://notifi.it/send?title=hello+world\n' +
      '\n' +
      'Encrypted.\n' +
      'Your device holds the only private key. Notifications are encrypted with your public key, so we cannot read them, and deleted from the server once your device has them.\n' +
      '\n' +
      'No accounts.\n' +
      'The app makes a send key on first launch. Keys can be renamed and revoked per source.\n' +
      '\n' +
      'Urgent alerts.\n' +
      'Mark a key as urgent and its notifications break through Focus.\n' +
      '',
    releaseNotes: 'Bug fixes and performance improvements.\n',

    shotInboxTitle: 'One request.\nStraight to your pocket.',
    shotInboxTitleIpad:
      'One HTTP request.\n' +
      'Straight to your devices.',
    shotInboxBody:
      'One HTTP request to notifi.it from anywhere. It’s on your device a moment later.',
    shotMessageTitle: 'Images, links,\nMarkdown.',
    shotMessageBody:
      'Title, body, image, link. The body is Markdown, rendered on your device.',
    shotKeysTitle: 'One key\nper source.',
    shotKeysBody:
      'One key for the deploy bot, another for the doorbell. Revoke one, the rest keep working.',
  },

  push: {
    fallbackTitle: 'notifi',
    fallbackBody: 'Open notifi to view',
    actionOpenLink: 'Open link',
    actionMarkAsRead: 'Mark as read',
    summaryFormat: '%%u more from {name}',
  },

  common: {
    cancel: 'Cancel',
    close: 'Close',
    delete: 'Delete',
    done: 'Done',
    copy: 'Copy',
    copied: 'Copied',
    share: 'Share',
    clear: 'Clear',
    search: 'Search',
    tryAgain: 'Try again',
    continueAction: 'Continue',
    quit: 'Quit',
    markAsRead: 'Mark as read',
    markAsUnread: 'Mark as unread',
    openLink: 'Open link',
    never: 'Never',
    moreActions: 'More actions',
    expand: 'Expand',
    collapse: 'Collapse',
  },

  tabs: {
    keys: 'Keys',
    settings: 'Settings',
    inbox: 'Inbox',
  },

  age: {
    now: 'now',
    justNow: 'just now',
    minutes: '{n}m',
    hours: '{n}h',
    days: '{n}d',
    weeks: '{n}w',
    ago: '{relative} ago',
  },

  inbox: {
    title: 'Inbox',
    count: plural('1 notification', '{n} notifications'),
    filteredToKey:
      'Showing “{name}” only.',
    closeSearch: 'Close search',
    markAllAsRead: 'Mark all as read',
    filterByKey: 'Filter by key',
    allKeys: 'All keys',
    refresh: 'Refresh',
    more: 'More',
    copyTitle: 'Copy title',
    copyMessage: 'Copy notification',
    copyLink: 'Copy link',
    seedSampleData: 'Seed sample data',
    clearSampleData: 'Clear sample data',

    bandToday: 'Today',
    bandYesterday: 'Yesterday',
    bandLabel: '{title}, {count}',

    unread: 'Unread',
    critical: 'Urgent',
    hasImage: 'Has an image',
    offlineBadge: 'Offline',
    linkTo: 'Link to {host}',
    deleteTitle: 'Delete “{title}”?',
    deleteTitleFallback: 'Delete this notification?',
    deleteMessage:
      'This can’t be undone.',
  },

  reader: {
    openInWindow: 'Open in window',
    openInMenuBar: 'Open in menu bar',
    selectPrompt: 'Select a notification',
    deleteSelectedTitle: 'Delete {count}?',
  },

  search: {
    prompt: 'Search inbox',
    matches: plural('1 match', '{n} matches'),
    recent: 'Recent',
  },

  message: {
    notFound: 'Notification not found',
    notFoundDetail:
      'It may have been deleted.',
    downloadImage: 'Download image',
    savingImage: 'Saving…',
    imageSaved: 'Saved to Photos',
    imageSavedToFile: 'Saved',
    imageSaveFailed: 'Couldn’t save the image',
    imageSaveDenied:
      'Allow notifi to add to Photos in Settings.',
    keyFallbackName: 'Key {id}',
    sentWithKey: 'Sent with key {name}',
    viewImageFullScreen:
      'Full screen',
    shareLink: 'Share link',
    imageFailedToLoad:
      'Couldn’t load image',
    imageHidden: 'Image hidden',
    imageHost: 'another host',
    imageLoadWarning:
      'Loading contacts {host}.',
    loadImage: 'Load image',
    load: 'Load',
    imageBlocked: 'blocked',
    image: 'Image',
    resetZoom: 'Reset zoom',
    linkBlockedNotice: 'Link blocked',
    sourceHeader: 'Source',
  },

  keys: {
    title: 'Keys',
    newKey: 'New key',
    sectionActive: 'Active',
    sectionRevoked: 'Revoked',
    aboutKeys: 'About keys',
    sent: plural('1 sent', '{n} sent'),
    rowLastUsed: 'used {ago}',
    docsLink: 'API docs',
    chipDefault: 'Device',
    chipCritical: 'Urgent',
    rowLabel: 'Key, {name}, ends {suffix}',
    rowLabelRevoked: ', revoked',
    rowLabelCritical: ', Urgent alerts on',
    maskedValue: '{prefix}…',
  },

  keyDetail: {
    notFound: 'Key not found',

    criticalTimeSensitive:
      'Lets API requests with is_critical=1 break through Focus.',

    copyKey: 'Copy key',
    shareKey: 'Share key',
    copyCurl: 'Copy curl',
    examplesLink: 'Docs',
    defaultKeyDetail:
      'Created automatically.',
    shownOnceDetail:
      'Shown once, when the key was created. Not stored on this device.',

    sectionUsage: 'Usage',
    fieldSent: 'Sent',
    fieldCreated: 'Created',
    fieldLastUsed: 'Last used',

    openAnyLink: 'Open any link',
    openAnyLinkDetail:
      'Opens links of any scheme, including ones that launch other apps. Off, only https.',

    criticalAlerts: 'Urgent alerts',

    revokedNotice:
      'Revoked. This key no longer accepts sends.',

    sectionDanger: 'Danger',
    regenerate: 'Regenerate key',
    regenerating: 'Regenerating…',
    regenerateDetail:
      'Issues a new value. API requests still using the old one will be rejected.',
    revoke: 'Revoke key',
    revoking: 'Revoking…',
    revokeDetail:
      'Revoking is permanent. Any API request still sending to this key will be rejected.',

    revokeTitle: 'Revoke “{name}”?',
    revokeTitleFallback: 'Revoke this key?',
    revokeConfirm: 'Revoke',
    revokeMessage:
      'API requests using this key will be rejected.',

    regenerateTitle: 'Regenerate “{name}”?',
    regenerateTitleFallback: 'Regenerate this key?',
    regenerateConfirm: 'Regenerate',
    regenerateMessage:
      'API requests still using the old value will be rejected.',

    regeneratedAnnouncement: 'Key regenerated. The old value no longer works.',
    revokedAnnouncement: 'Key revoked.',

  },

  createKey: {
    title: 'New key',
    intro:
      'Only you see it. It labels the key in the list and in filters.',
    sectionName: 'Name',
    namePrompt: 'e.g. Grafana alerts',
    nameLabel: 'Key name',
    charCount: '{n}/{max}',
    nameReserved:
      '“device” is taken by your device’s own key.',
    nameTaken:
      'An active key already has this name.',
    create: 'Create key',
    creating: 'Creating…',

    validationEmpty:
      'Enter a name.',
    validationTooLong:
      '{max} characters or fewer.',

    revealTitle:
      'Copy your key',
    revealDetail: "It won’t be shown again.",
    revealLabel: 'Your new key',
    revealWarning:
      'Treat it like a password. If you lose it, revoke it and make a new one.',

    leaveTitle: "Haven’t copied it?",
    leaveCopyAndClose: 'Copy and close',
    leaveCloseAndRevoke: 'Close and revoke',
    leaveMessage:
      'It won’t be shown again.',
  },

  settings: {
    title: 'Settings',

    sectionPermissions: 'Permissions',
    permission: 'Permission',
    openSystemSettings: 'Open system settings',

    permissionEnabled: 'Enabled',
    permissionOff: 'Off',
    permissionProvisional: 'Provisional',
    permissionEphemeral: 'Ephemeral',
    permissionNotSet: 'Not set',
    permissionUnknown: 'Unknown',

    stayVisible: 'Notifications stay visible',
    stayVisibleDetail:
      'Notifications stay on screen until you dismiss them.',
    stayVisibleEnable: 'Enable',

    theme: 'Theme',
    grain: 'Grain',
    themeDark: 'Dark',
    themeLight: 'Light',
    themeSystem: 'System',

    loadImages: 'Load images automatically',
    loadImagesDetail:
      'Loads images automatically.',

    strictSend: 'Reject invalid sends',
    strictSendDetail:
      'Refuses an API request whose title or body is over length.\n' +
      '\n' +
      'When turned off, the field is cropped and the send is accepted with a warnings array.\n' +
      '\n' +
      '[For more information see the docs](https://notifi.it/docs#response)',

    testTitle: 'Hello from notifi',
    testBody: 'Your first notification.',

    macApp:
      'Get notifi for Mac',
    iosApp:
      'Get notifi for iPhone and iPad',

    sectionSupport: 'Support',
    sectionApplication: 'Application',
    sectionAbout: 'About',
    version: 'Version',
    openAtLogin: 'Open at login',
    openAtLoginDetail:
      'Starts notifi in the menu bar at login.',
    installUpdatesAutomatically: 'Install updates automatically',
    installUpdatesAutomaticallyDetail: 'Download and install new versions without asking. notifi relaunches itself when it updates.',
    checkForUpdates: 'Check for updates',
    deleteAll: 'Delete all notifications',
    deleteAllTitle: 'Delete all notifications?',
    deleteAllConfirm: 'Delete all',
    deleteAllMessage: "This can’t be undone.",
    support: 'Report a problem',
    feedback: 'Feedback',
    privacyPolicy: 'Privacy policy',
    website: 'notifi.it',
    docs: 'Docs',
  },

  empty: {
    sampleTitle: 'Hello from notifi',
    sampleMessage: 'Your first notification.',

    title: 'Nothing yet',
    detail:
      'Your first notification appears here.',

    stepAllow: 'Allow notifications',
    notificationsOn: 'Notifications are on.',
    enableNotifications: 'Enable notifications',

    stepSend: 'Send one',
    sendTest: 'Send a test',
    sending: 'Sending…',
    sent:
      'Sent.',

    makingKey: 'Making your key…',

    stepLabel: 'Step {n}. {title}.',
    stepDone: ' Done.',
  },

  components: {
    clearSearch: 'Clear search',
    noMatches: 'No matches',
    noMatchesDetail:
      'Nothing matches that filter.',
    noMatchesQuery: 'Nothing matching “{query}”.',
    errorLabel: 'Error. {message}',
    backTo: 'Back to {label}',
    createKey: 'Create key',
  },

  identity: {
    title: "Can’t unlock notifi",
    detail:
      'notifi couldn’t read its identity key. Unlock the device and try again.',
  },

  unsupported: {
    title: 'Unsupported Mac',
    detail:
      'notifi needs a Mac with Apple silicon or a T2 chip.',
  },

  restore: {
    title:
      'New device',
    detail:
      'Your notifications were restored, but keys can’t move between devices. Your old keys no longer work. Create new ones.',
  },

  clientErrors: {
    unauthorized:
      'This key no longer works. Create a new one under Keys.',
    notFound:
      'No longer on the server. Refresh and try again.',
    rateLimited:
      'Too many requests. Try again.',
    server:
      'Server error. Try again.',
    generic:
      'Request failed. Try again.',
    transport:
      'Couldn’t reach notifi’s servers. Check your connection and try again.',
    decoding:
      'Unexpected reply from the server. Try again.',
  },
};

export type Strings = typeof copy;
