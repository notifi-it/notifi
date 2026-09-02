import type { Plural } from './types.js';

function plural(one: string, other: string): Plural {
  return { one, other };
}

export const copy = {
  api: {
    notFound: 'Not found.',
    unexpected: 'Unexpected error.',

    rateLimitedIP: 'Too many requests from this IP.',
    rateLimitedAccount: 'Rate limit exceeded. Too many notifications this hour.',

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
    criticalNotAllowed:
      'Sent as a normal notification, because critical alerts are switched off for this key.',
    titleCropped: 'Sent with a shortened title, because it was over {max} characters.',
    messageCropped: 'Sent with a shortened notification, because it was over {max} characters.',
    strictContentRejected:
      'Not sent. This device is set to refuse a notification it cannot deliver as written.',

  },

  store: {
    name: 'notifi: Push Notifications',
    subtitle: 'For scripts and servers',
    promotionalText:
      "One HTTP request, and the notification is on your iPhone or Mac. Encrypted with " +
      "your public key, so we can’t read your notifications. No accounts.",
    keywords:
      'webhook,api,notify,alerts,self,hosted,cron,curl,cli,devops,homelab,ssh,docker,' +
      'terminal,developer',
    description:
      'Push notifications for your scripts and servers.\n\n' +
      'Create a send key and send a title and a body to notifi.it in one HTTP request. ' +
      'The notification lands on your iPhone or Mac. Anything that can make an HTTP request ' +
      'can send one, e.g. a shell script, a cron job, a CI pipeline.\n\n' +
      'https://notifi.it/send?title=hello+world\n\n' +
      'WHAT A NOTIFICATION CARRIES\n' +
      'A title, a body, an image and a link. The body is Markdown: headings, lists, ' +
      'quotes, links and code blocks are rendered on the device.\n\n' +
      'ENCRYPTED\n' +
      'Your device holds the only private key. Notification content is encrypted with your public ' +
      'key at ingest, so we cannot read your notifications. Each one is deleted from the server ' +
      'once your device acknowledges it.\n\n' +
      'NO ACCOUNTS\n' +
      'No sign-up, no sign-in, no device linking. The app mints a send key on first launch. ' +
      'Keys can be renamed, paused and revoked per source.\n\n' +
      'URGENT ALERTS\n' +
      'Mark a key as urgent and its notifications break through Focus and land on the lock ' +
      'screen.\n',
    releaseNotes: 'Bug fixes and performance improvements.\n',

    shotInboxTitle: 'One request.\nStraight to your pocket.',
    shotInboxTitleIpad: 'One request.\nStraight to your devices.',
    shotInboxBody:
      'Push notifications for your scripts and servers. One HTTP request to notifi.it and ' +
      'it arrives a moment later. No account.',
    shotMessageTitle: 'Images, links,\nMarkdown.',
    shotMessageBody:
      'A title, a body, an image and a link. Headings, lists, quotes and code blocks are ' +
      'rendered on the device. Encrypted with your public key, so we cannot read your notifications.',
    shotKeysTitle: 'One key\nper source.',
    shotKeysBody:
      'Give the deploy bot one key and the doorbell another. Revoke one and the rest keep ' +
      'working. Each key carries its own send count, and there is no account to make first.',
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
    minutes: '{n} min',
    hours: '{n} hr',
    days: '{n} d',
    weeks: '{n} w',
    ago: '{relative} ago',
  },

  inbox: {
    title: 'Inbox',
    offline: "Can’t reach notifi servers. Check your connection and try again.",
    count: plural('1 notification', '{n} notifications'),
    filteredToKey: 'Filtered to the “{name}” key.',
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
    critical: 'Critical',
    linkTo: 'Link to {host}',
    deleteTitle: 'Delete “{title}”?',
    deleteTitleFallback: 'Delete this notification?',
    deleteMessage: 'This cannot be undone.',
  },

  search: {
    prompt: 'Search inbox',
    matches: plural('1 match', '{n} matches'),
    recent: 'Recent',
  },

  message: {
    notFound: 'Notification not found',
    notFoundDetail: 'It may have been deleted on this device.',
    downloadImage: 'Download image',
    savingImage: 'Saving…',
    imageSaved: 'Saved to Photos',
    imageSavedToFile: 'Saved',
    imageSaveFailed: 'Couldn’t save the image',
    imageSaveDenied: 'notifi needs permission to add to Photos. Turn it on in Settings.',
    keyFallbackName: 'Key {id}',
    sentWithKey: 'Sent with key {name}',
    openKey: 'Sent with key {name}. Open it.',
    viewImageFullScreen: 'View image full screen',
    shareLink: 'Share link',
    imageFailedToLoad: 'Image failed to load',
    imageHidden: 'Image hidden',
    imageHost: 'another host',
    imageLoadWarning: 'Loading it contacts {host}.',
    loadImage: 'Load image',
    load: 'Load',
    imageBlocked: 'blocked',
    sourceHeader: 'Source',
  },

  keys: {
    title: 'Keys',
    newKey: 'New key',
    refreshFailed: "Couldn’t refresh keys. Showing the last known list.",
    sectionActive: 'Active',
    sectionRevoked: 'Revoked',
    aboutKeys: 'About keys',
    sent: plural('1 sent', '{n} sent'),
    rowLastUsed: 'used {ago}',
    docsLink: 'API docs',
    chipDefault: 'Default',
    chipCritical: 'Critical',
    rowLabel: 'Key, {name}, ends {suffix}',
    rowLabelRevoked: ', revoked',
    rowLabelCritical: ', Critical Alerts on',
    maskedValue: '{prefix}…',
  },

  keyDetail: {
    notFound: 'Key not found',
    notFoundDetail: 'It may have been removed on another device.',

    criticalOn:
      'Sends from this key that ask for it will sound through silent mode and Focus. ' +
      'Add is_critical=1 to the send.',
    criticalTimeSensitive:
      'Sends from this key that ask for it break through Focus and stay on the lock ' +
      'screen. Add is_critical=1 to the send. They will not sound through silent mode. ' +
      'That needs an entitlement Apple has yet to grant notifi.',

    copyKey: 'Copy key',
    shareKey: 'Share key',
    copyCurl: 'Copy curl',
    examplesLink: 'Docs',
    defaultKeyDetail:
      'notifi keeps this one on your device, so you can copy it again whenever you ' +
      'need it, or regenerate it below.',
    shownOnceDetail:
      'The value was shown once, when you created this key. It is not stored on the device.',

    sectionUsage: 'Usage',
    fieldSent: 'Sent',
    fieldCreated: 'Created',
    fieldLastUsed: 'Last used',

    openAnyLink: 'Open any link',
    openAnyLinkDetail:
      'Off, only https links open. On, other schemes open too, including ones that ' +
      'launch other apps on this device.',

    criticalAlerts: 'Critical alerts',

    revokedNotice: 'This key is revoked and no longer accepts sends.',

    sectionDanger: 'Danger',
    regenerate: 'Regenerate key',
    regenerating: 'Regenerating…',
    regenerateDetail:
      'Regenerating issues a new value and retires the old one. Anything still sending ' +
      'with the old value will be rejected.',
    revoke: 'Revoke key',
    revoking: 'Revoking…',
    revokeDetail:
      'Revoking is permanent. Anything still sending to this key will be rejected.',

    revokeTitle: 'Revoke “{name}”?',
    revokeTitleFallback: 'Revoke this key?',
    revokeConfirm: 'Revoke',
    revokeMessage: 'Anything still sending to it will be rejected.',

    regenerateTitle: 'Regenerate “{name}”?',
    regenerateTitleFallback: 'Regenerate this key?',
    regenerateConfirm: 'Regenerate',
    regenerateMessage:
      'The current value stops working immediately, and anything still sending with it ' +
      'will be rejected.',

    regeneratedAnnouncement: 'Key regenerated. The old value no longer works.',
    regenerateFailed: "Couldn’t regenerate the key. Check your connection and try again.",
    revokedAnnouncement: 'Key revoked.',
    revokeFailed: "Couldn’t revoke the key. Check your connection and try again.",

    criticalNotPermitted:
      'Critical Alerts are turned off for notifi in system settings. These will still ' +
      'break through Focus, but they will not sound through silent mode.',
    criticalChangeFailed:
      "Couldn’t change critical alerts for this key. Check your connection and try again.",
  },

  createKey: {
    title: 'New key',
    intro: 'A name only you see. It shows up on the key list and in filters.',
    sectionName: 'Name',
    namePrompt: 'e.g. Grafana alerts',
    nameLabel: 'Key name',
    charCount: '{n}/{max}',
    nameReserved: '“default” is reserved. Your device already has one.',
    nameTaken: 'A key with this name is already active.',
    create: 'Create key',
    creating: 'Creating…',

    validationEmpty: 'Enter a name for this key.',
    validationTooLong: 'Use 64 characters or fewer.',
    validationReserved: "Choose another name. “default” is your device’s own key.",
    validationTaken: 'Choose another name. One of your active keys already has this one.',
    createFailed: "Couldn’t create the key. Check your connection and try again.",

    revealTitle: 'Copy your key now',
    revealDetail: "It won’t be shown again.",
    revealLabel: 'Your new key',
    revealWarning:
      'Treat it like a password. If you lose it, revoke the key and make a new one.',

    leaveTitle: "Haven’t copied it?",
    leaveCopyAndClose: 'Copy and close',
    leaveCloseAndRevoke: 'Close and revoke',
    leaveMessage: 'This key will never be shown again.',
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
      'A notification stays on screen until you click or dismiss it, instead of leaving after ' +
      'a few seconds. Enable opens System Settings, where you choose notifi’s alert style.',
    stayVisibleEnable: 'Enable',

    theme: 'Theme',
    themeDark: 'Dark',
    themeLight: 'Light',
    themeSystem: 'System',

    loadImages: 'Load images automatically',
    loadImagesDetail:
      'Fetches each image as the notification arrives, which tells its host your IP address. ' +
      'Off, images load only when tapped.',

    strictSend: 'Reject invalid sends',
    strictSendDetail:
      'Returns 422 invalid_content and stores nothing when a title or body is over ' +
      'length. Off, /send crops the field and returns 202 with a warnings array.',
    strictSendFailed: 'PATCH /devices/settings failed. Check your connection and try again.',

    testTitle: 'Hello from notifi',
    testBody: 'Your first notification.',

    macApp: 'Download notifi for Mac',
    iosApp: 'Download notifi for iOS',

    sectionSupport: 'Support',
    sectionApplication: 'Application',
    sectionAbout: 'About',
    version: 'Version',
    openAtLogin: 'Open at login',
    openAtLoginDetail: 'Starts notifi in the menu bar when you log in to this Mac.',
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
  },

  empty: {
    sampleTitle: 'Hello from notifi',
    sampleMessage: 'Your first notification.',

    title: 'Nothing yet',
    detail: 'Send your first notification and it lands here.',

    stepAllow: 'Allow notifications',
    notificationsOn: 'Notifications are on.',
    enableNotifications: 'Enable notifications',

    stepSend: 'Send one',
    sendTest: 'Send a test',
    sending: 'Sending…',
    sent: 'Sent. It arrives here and on your lock screen in a moment.',
    sendFailed: "Couldn’t send. Check your connection and try again.",

    makingKey: 'Making your key…',
    makeKeyFailed: "Couldn’t make a key. Check your connection and try again.",

    stepLabel: 'Step {n}. {title}.',
    stepDone: ' Done.',
  },

  components: {
    clearSearch: 'Clear search',
    noMatches: 'No matches',
    noMatchesDetail: 'Nothing here with that filter.',
    noMatchesQuery: 'Nothing matching “{query}”.',
    errorLabel: 'Error. {message}',
    backTo: 'Back to {label}',
    createKey: 'Create key',
  },

  identity: {
    title: "Can’t unlock notifi",
    detail:
      'notifi could not read its identity key from the keychain. This usually clears once the ' +
      'device has been unlocked. Your notifications and send keys are unaffected.',
  },

  unsupported: {
    title: 'Unsupported Mac',
    detail:
      'notifi requires a Mac with Apple silicon or a T2 chip. This Mac has no Secure Enclave, ' +
      'which notifi uses to protect your identity key.',
  },

  restore: {
    title: 'This looks like a new device',
    detail:
      'Your old notifications restored from a backup, but your keys did not. Keys are tied to the ' +
      'device they were created on and cannot be moved. Anything still sending to your old keys ' +
      'will now be rejected. Create fresh keys to keep receiving notifications.',
  },

  clientErrors: {
    unauthorized: 'This key is no longer accepted. Create a new one under Keys.',
    notFound: 'That is no longer on the server. Refresh and try again.',
    rateLimited: 'Too many requests just now. Try again in a moment.',
    server: 'The server is having trouble. Try again in a moment.',
    generic: "The request didn’t go through. Try again.",
    transport: "Couldn’t reach the server. Check your connection and try again.",
    decoding: 'The server returned something unexpected. Try again in a moment.',
  },
};

export type Strings = typeof copy;
