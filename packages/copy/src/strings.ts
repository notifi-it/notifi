// Every sentence the product says to a person, written in the source language.
// Translations live beside this file in `translations/<code>.ts` as flat maps of
// dotted key to string, so a translator never has to read this structure.
//
// Placeholders are `{name}`, and become a positional argument in the order they
// first appear. A value carrying one is a function on both sides.
//
// Counted things use `plural(one, other)` rather than two keys. English needs
// only the pair, but the leaf tells the string catalog that the value varies by
// number, which is what lets a language with six plural forms have six. The
// `other` case must carry `{n}` and the leaf may carry no other placeholder --
// anything that mixes a count with other text composes the two, the way
// `inbox.bandLabel` takes an already-rendered count.

import type { Plural } from './types.js';

function plural(one: string, other: string): Plural {
  return { one, other };
}

export const copy = {
  // ---------------------------------------------------------------------------
  // Server responses. The app prefers these over its own fallbacks whenever the
  // response carries a message, so these are the sentences a person actually
  // reads for anything the server refused.
  // ---------------------------------------------------------------------------
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
    invalidHistoryQuery: 'Invalid history query.',
    invalidSendParams: 'Invalid send parameters.',
    occurredAtTooFuture: 'occurred_at is too far in the future.',

    noMacBuild: 'No macOS build has been published yet.',
    noSuchBuild: 'No such build.',
  },

  // ---------------------------------------------------------------------------
  // Push payloads. Written by the server, rendered by the OS, and repeated by
  // the notification service extension when it cannot decrypt the real content.
  // ---------------------------------------------------------------------------
  push: {
    /// The alert title on the wire. The extension replaces it with the decrypted
    /// title; this is what shows if it never gets to run.
    fallbackTitle: 'notifi',
    fallbackBody: 'Open notifi to view',
    actionOpenLink: 'Open link',
    actionMarkAsRead: 'Mark as read',
    /// `%u` is claimed by the OS, which fills in the collapsed count.
    summaryFormat: '%u more from {name}',
  },

  // ---------------------------------------------------------------------------
  // Words the app reuses everywhere. A change here moves every screen, which is
  // the point: these drifted apart when each screen owned its own copy.
  // ---------------------------------------------------------------------------
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
    expand: 'Expand',
    collapse: 'Collapse',
  },

  tabs: {
    notifications: 'Notifications',
    keys: 'Keys',
    settings: 'Settings',
    inbox: 'Inbox',
  },

  // ---------------------------------------------------------------------------
  // Relative ages. One ladder, used by the inbox rows and the message header,
  // which held two identical copies of it.
  // ---------------------------------------------------------------------------
  age: {
    now: 'now',
    justNow: 'just now',
    minutes: '{n} min',
    hours: '{n} hr',
    days: '{n} d',
    weeks: '{n} w',
    ago: '{relative} ago',
    /// Shown under the title on the message screen, to the millisecond, because
    /// the point of that line is telling two near-simultaneous alerts apart.
    absoluteFormat: 'EEE d MMM yyyy, HH:mm:ss.SSS',
  },

  inbox: {
    title: 'Notifications',
    count: plural('1 notification', '{n} notifications'),
    unreadSummary: ' unread · {total}',
    filteredToKey: 'Filtered to the “{name}” key.',
    closeSearch: 'Close search',
    markAllAsRead: 'Mark all as read',
    filterByKey: 'Filter by key',
    allKeys: 'All keys',
    refresh: 'Refresh',
    more: 'More',
    copyTitle: 'Copy title',
    copyMessage: 'Copy message',
    copyLink: 'Copy link',
    seedSampleData: 'Seed sample data',
    clearSampleData: 'Clear sample data',

    bandToday: 'Today',
    bandYesterday: 'Yesterday',
    bandEarlierThisWeek: 'Earlier This Week',
    bandEarlierThisMonth: 'Earlier This Month',
    bandLabel: '{title}, {count}',

    unread: 'Unread',
    critical: 'Critical',
    linkTo: 'Link to {host}',
    rowKey: 'Key {label}',

    deleteTitle: 'Delete “{title}”?',
    deleteTitleFallback: 'Delete this notification?',
    deleteMessage: 'This cannot be undone.',
  },

  search: {
    prompt: 'Search notifications',
    matches: plural('1 match', '{n} matches'),
  },

  message: {
    notFound: 'Message not found',
    notFoundDetail: 'It may have been deleted on this device.',
    downloadImage: 'Download image',
    backToNotifications: 'Back to Notifications',
    keyFallbackName: 'Key {id}',
    sentWithKey: 'Sent with key {name}',
    viewImageFullScreen: 'View image full screen',
    linksTo: 'Links to {host}',
    shareLink: 'Share link',
    imageFailedToLoad: 'Image failed to load',
    imageHidden: 'Image hidden',
    imageHost: 'another host',
    imageLoadWarning: 'Loading it contacts {host}.',
    loadImage: 'Load image',
  },

  keys: {
    title: 'Keys',
    newKey: 'New key',
    active: plural('1 active', '{n} active'),
    criticalSummary: '{active} · {n} critical',
    refreshFailed: "Couldn't refresh keys. Showing the last known list.",
    sectionActive: 'Active',
    sectionRevoked: 'Revoked',
    emptyTitle: 'No active keys yet',
    emptyDetail:
      'A key is what a script sends with. Make one per source so you can revoke them separately.',
    footnote:
      'A key is shown once, when it is created; notifi stores only the prefix. ' +
      'The default key can be copied again or regenerated from its detail page.',
    sent: plural('1 sent', '{n} sent'),
    chipDefault: 'Default',
    chipRevoked: 'Revoked',
    chipCritical: 'Critical',
    rowLabel: 'Key, {name}, ends {suffix}',
    rowLabelRevoked: ', revoked',
    rowLabelCritical: ', Critical Alerts on',
    /// The value is shown truncated everywhere but the one screen that created it.
    maskedValue: '{prefix}…',
  },

  keyDetail: {
    notFound: 'Key not found',
    notFoundDetail: 'It may have been removed on another device.',

    criticalOn:
      'Sends from this key that ask for it will sound through silent mode and Focus. ' +
      'Add is_critical=1 to the send.',
    /// What the switch buys without the Critical Alerts entitlement, which is
    /// still the usual case: Time Sensitive, which needs no grant from Apple.
    criticalTimeSensitive:
      'Sends from this key that ask for it break through Focus and stay on the lock ' +
      'screen. Add is_critical=1 to the send. They will not sound through silent mode — ' +
      'that needs an entitlement Apple has yet to grant notifi.',

    copyKey: 'Copy key',
    shareKey: 'Share key',
    copyCurl: 'Copy curl',
    defaultKeyDetail:
      'notifi keeps this one on your device, so you can copy it again whenever you ' +
      'need it, or regenerate it below.',
    shownOnceDetail:
      'The value was shown once, when you created this key. It is not stored on the device.',

    sectionUsage: 'Usage',
    fieldSent: 'Sent',
    fieldCreated: 'Created',
    fieldLastUsed: 'Last used',

    sectionLinks: 'Links',
    openAnyLink: 'Open any link',
    openAnyLinkDetail:
      'Off, only https links open. On, other schemes open too, including ones that ' +
      'launch other apps on this device.',

    sectionAlerts: 'Alerts',
    criticalAlerts: 'Urgent alerts',

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
    regenerateFailed: "Couldn't regenerate the key. Check your connection and try again.",
    revokedAnnouncement: 'Key revoked.',
    revokeFailed: "Couldn't revoke the key. Check your connection and try again.",

    criticalNotPermitted:
      'Critical Alerts are turned off for notifi in system settings. These will still ' +
      'break through Focus, but they will not sound through silent mode.',
    criticalChangeFailed:
      "Couldn't change urgent alerts for this key. Check your connection and try again.",
  },

  createKey: {
    title: 'New key',
    intro: 'A name only you see. It shows up on the key list and in filters.',
    sectionName: 'Name',
    namePrompt: 'e.g. Grafana alerts',
    nameLabel: 'Key name',
    nameReserved: '“default” is reserved — your device already has one.',
    create: 'Create key',
    creating: 'Creating…',

    validationEmpty: 'Enter a name for this key.',
    validationTooLong: 'Use 64 characters or fewer.',
    validationReserved: "Choose another name — “default” is your device's own key.",
    createFailed: "Couldn't create the key. Check your connection and try again.",

    revealTitle: 'Copy your key now',
    revealDetail: 'This is the only time it is shown.',
    revealLabel: 'Your new key',
    revealWarning:
      'This key lives and dies with this device. If you lose the device, the key stops ' +
      'working and cannot be recovered.',

    leaveTitle: "Haven't copied it?",
    leaveCopyAndClose: 'Copy and close',
    leaveCloseAndRevoke: 'Close and revoke',
    leaveMessage: 'This key will never be shown again.',
  },

  settings: {
    title: 'Settings',

    sectionNotifications: 'Notifications',
    permission: 'Permission',
    openSystemSettings: 'Open system settings',

    permissionEnabled: 'Enabled',
    permissionOff: 'Off',
    permissionProvisional: 'Provisional',
    permissionEphemeral: 'Ephemeral',
    delivery: 'Delivery',
    deliveryBroken: 'Not pushing',
    deliveryBrokenDetail:
      'Recent messages arrived without a notification behind them. Notifications '
      + 'are not reaching this device; messages still arrive over its live '
      + 'connection, and whenever the app opens or refreshes.',
    permissionNotSet: 'Not set',
    permissionUnknown: 'Unknown',

    sectionAppearance: 'Appearance',
    ground: 'Ground',
    groundDark: 'Dark',
    groundLight: 'Light',
    groundDetail:
      'The app starts dark whatever the phone is set to, and stays on whichever of these ' +
      'you pick.',

    sectionPrivacy: 'Privacy',
    loadImages: 'Load images automatically',
    loadImagesDetail:
      'Fetching an image tells the sender your IP address and when it arrived. Off, images ' +
      'load only when tapped.',

    sectionDiagnostics: 'Diagnostics',
    sendTest: 'Send test notification',
    sendTestDetail: 'Sends through your default key.',
    testSent: 'Sent. It should arrive momentarily.',
    testNoDefaultKey: 'No default key on this device yet. Refresh and try again.',
    testFailed: "Couldn't send the test. Check your connection and try again.",
    testTitle: 'Test notification',
    testBody: 'If you can read this, notifi is working.',

    sectionAbout: 'About',
    version: 'Version',
    automaticUpdates: 'Automatic updates',
    automaticUpdatesDetail: 'Check for new versions in the background.',
    checkForUpdates: 'Check for updates',
    privacyPolicy: 'Privacy policy',
    website: 'notifi.it',
    keysAreDeviceBound:
      'Keys live and die with this device. If you lose it, the keys stop working and cannot ' +
      'be recovered.',
  },

  empty: {
    sampleTitle: 'It lives',
    sampleMessage: 'notifi is working.',

    title: 'Nothing yet',
    detail: 'Send your first notification and it lands here.',

    stepAllow: 'Allow notifications',
    notificationsOn: 'Notifications are on.',
    enableNotifications: 'Enable notifications',

    stepSend: 'Send one',
    sendTest: 'Send a test',
    sending: 'Sending…',
    sent: 'Sent. It arrives here and on your lock screen in a moment.',
    sentDetail:
      'It arrives here and on your lock screen. Make more keys under Keys to keep sources apart.',
    sendFailed: "Couldn't send. Check your connection and try again.",

    makingKey: 'Making your key…',
    makeKeyFailed: "Couldn't make a key. Check your connection and try again.",

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
    wordmark: 'notifi',
  },

  identity: {
    title: "Can't unlock notifi",
    detail:
      'notifi could not read its identity key from the keychain. This usually clears once the ' +
      'device has been unlocked. Your messages and send keys are unaffected.',
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
      'Your old messages restored from a backup, but your keys did not. Keys are tied to the ' +
      'device they were created on and cannot be moved. Anything still sending to your old keys ' +
      'will now be rejected — create fresh keys to keep receiving notifications.',
  },

  // ---------------------------------------------------------------------------
  // What the app says when the server said nothing usable: a transport failure,
  // or a status with no message body. Anything the server does send is shown
  // as-is, so these are fallbacks and not the primary wording.
  // ---------------------------------------------------------------------------
  clientErrors: {
    unauthorized: 'This key is no longer accepted. Create a new one under Keys.',
    notFound: 'That is no longer on the server. Refresh and try again.',
    rateLimited: 'Too many requests just now. Try again in a moment.',
    server: 'The server is having trouble. Try again in a moment.',
    generic: "The request didn't go through. Try again.",
    transport: "Couldn't reach the server. Check your connection and try again.",
    decoding: 'The server returned something unexpected. Try again in a moment.',
  },
};

export type Strings = typeof copy;
