import type { Translation } from '../types.js';

export const de: Translation = {
  'api.notFound': 'Nicht gefunden.',
  'api.unexpected': 'Unerwarteter Fehler.',

  'api.rateLimitedIP': 'Zu viele Anfragen von dieser IP.',
  'api.rateLimitedAccount': 'Limit erreicht. Zu viele Benachrichtigungen in dieser Stunde.',

  'api.badSignature': 'Ungültige Anfragesignatur.',
  'api.staleTimestamp': 'Der Zeitstempel der Anfrage liegt außerhalb des zulässigen Fensters.',

  'api.unknownDevice': 'Gerät ist nicht registriert.',
  'api.unknownKey': 'Unbekannter oder widerrufener Schlüssel.',
  'api.keyNotFound': 'Schlüssel nicht gefunden.',
  'api.activeKeyLimit': 'Limit für aktive Schlüssel erreicht.',

  'api.invalidDeviceBody': 'Ungültiger Text für die Geräteregistrierung.',
  'api.publicKeyMismatch': 'public_key muss mit dem signierenden öffentlichen Schlüssel übereinstimmen.',
  'api.invalidEncryptionKey': 'encryption_public_key ist kein gültiger P-256-Punkt.',
  'api.invalidCreateKeyBody': 'Ungültiger Text zum Erstellen eines Schlüssels.',
  'api.invalidUpdateKeyBody': 'Ungültiger Text zum Aktualisieren eines Schlüssels.',
  'api.invalidDeviceSettingsBody': 'Ungültiger Text für Geräteeinstellungen.',
  'api.invalidHistoryQuery': 'Ungültige Verlaufsabfrage.',
  'api.invalidSendParams': 'Ungültige Sendeparameter.',
  'api.occurredAtTooFuture': 'occurred_at liegt zu weit in der Zukunft.',
  'api.criticalNotAllowed':
    'Als normale Benachrichtigung gesendet: Kritische Benachrichtigungen sind für diesen Schlüssel deaktiviert.',
  'api.titleCropped': 'Mit gekürztem Titel gesendet: Er war länger als {max} Zeichen.',
  'api.messageCropped': 'Mit gekürzter Nachricht gesendet: Sie war länger als {max} Zeichen.',
  'api.imageRejected': 'Ohne Bild gesendet: Diese Adresse rufen wir nicht ab.',
  'api.imageUnreachable':
    'Ohne Bild gesendet: Es kam keine Antwort als PNG, JPEG oder GIF unter 5 MB.',
  'api.strictContentRejected':
    'Nicht gesendet. Dieses Gerät ist so eingestellt, dass es eine nicht wie geschrieben zustellbare Nachricht ablehnt.',


  'store.subtitle': 'Eine Anfrage, ein Push',
  'store.promotionalText':
    'Eine HTTP-Anfrage, und sie landet auf deinem iPhone oder Mac. Mit deinem ' +
    'öffentlichen Schlüssel verschlüsselt — wir können sie nicht lesen. ' +
    'Kein Account, kein SDK.',
  'store.keywords':
    'curl,webhook,api,alarm,cli,server,überwachung,cron,skript,entwickler,terminal,' +
    'devops,homelab,pager',
  'store.description':
    'Push-Benachrichtigungen für deine Skripte und Server.\n\n' +
    'Erstelle einen Sendeschlüssel und schicke einen Titel und eine Nachricht in einer ' +
    'HTTP-Anfrage an notifi.it. Die Benachrichtigung landet auf deinem iPhone oder Mac. ' +
    'Alles, was eine HTTP-Anfrage stellen kann, kann eine senden, z. B. ein Shell-Skript, ' +
    'ein Cron-Job, eine CI-Pipeline.\n\n' +
    'https://notifi.it/send?title=hello+world\n\n' +
    'WAS EINE NACHRICHT ENTHÄLT\n' +
    'Einen Titel, einen Text, ein Bild und einen Link. Der Text ist Markdown: Überschriften, ' +
    'Listen, Zitate, Links und Codeblöcke werden auf dem Gerät dargestellt.\n\n' +
    'VERSCHLÜSSELT\n' +
    'Nur dein Gerät besitzt den privaten Schlüssel. Der Nachrichteninhalt wird beim ' +
    'Empfang mit deinem öffentlichen Schlüssel verschlüsselt, sodass wir deine ' +
    'Nachrichten nicht lesen können. Jede Nachricht wird vom Server gelöscht, sobald ' +
    'dein Gerät sie bestätigt hat.\n\n' +
    'KEINE ACCOUNTS\n' +
    'Keine Anmeldung, kein Login, keine Geräteverknüpfung. Die App erstellt beim ersten ' +
    'Start einen Sendeschlüssel. Schlüssel lassen sich pro Quelle umbenennen, pausieren ' +
    'und widerrufen.\n\n' +
    'DRINGENDE BENACHRICHTIGUNGEN\n' +
    'Markiere einen Schlüssel als dringend, und seine Benachrichtigungen durchbrechen ' +
    'den Fokus und landen auf dem Sperrbildschirm.\n',
  'store.releaseNotes':
    'notifi 2.0 ist eine komplette Neuentwicklung. Die alte Flutter-App ist verschwunden; ' +
    'diese ist nativ in Swift geschrieben, von Grund auf neu gestaltet.\n\n' +
    'Schnellerer Start, natives Text-Rendering und ein gemeinsames Layout für alle drei ' +
    'Tabs. Der Bildschirm Schlüssel sagt jetzt, wofür ein Schlüssel steht, und der ' +
    'eingebaute Standardschlüssel führt die Liste an. Zeitstempel bei Nachrichten sind ' +
    'reine Ziffern, die sich kopieren lassen.\n',

  'store.shotInboxTitle': 'Eine Anfrage.\nDirekt in deine Tasche.',
  'store.shotInboxBody':
    'Push-Benachrichtigungen für deine Skripte und Server. Eine HTTP-Anfrage an notifi.it, ' +
    'und sie kommt einen Moment später an. Kein Account, kein SDK.',
  'store.shotMessageTitle': 'Bilder, Links,\nMarkdown.',
  'store.shotMessageBody':
    'Ein Titel, ein Text, ein Bild und ein Link. Überschriften, Listen, Zitate und ' +
    'Code-Blöcke werden auf dem Gerät gerendert. Mit deinem öffentlichen Schlüssel ' +
    'verschlüsselt, sodass wir deine Nachrichten nicht lesen können.',
  'store.shotKeysTitle': 'Ein Schlüssel\npro Quelle.',
  'store.shotKeysBody':
    'Gib dem Deploy-Bot einen Schlüssel und der Türklingel einen anderen. Widerrufe ' +
    'einen, und der Rest funktioniert weiter. Jeder Schlüssel führt seine eigene ' +
    'Sendeanzahl, und es ist kein Account nötig.',

  'push.fallbackTitle': 'notifi',
  'push.fallbackBody': 'notifi öffnen, um es anzuzeigen',
  'push.actionOpenLink': 'Link öffnen',
  'push.actionMarkAsRead': 'Als gelesen markieren',
  'push.summaryFormat': '%%u weitere von {name}',

  'common.cancel': 'Abbrechen',
  'common.close': 'Schließen',
  'common.delete': 'Löschen',
  'common.done': 'Fertig',
  'common.copy': 'Kopieren',
  'common.copied': 'Kopiert',
  'common.share': 'Teilen',
  'common.clear': 'Leeren',
  'common.search': 'Suchen',
  'common.tryAgain': 'Erneut versuchen',
  'common.continueAction': 'Weiter',
  'common.quit': 'Beenden',
  'common.markAsRead': 'Als gelesen markieren',
  'common.markAsUnread': 'Als ungelesen markieren',
  'common.openLink': 'Link öffnen',
  'common.never': 'Nie',
  'common.expand': 'Erweitern',
  'common.collapse': 'Einklappen',

  'tabs.keys': 'Schlüssel',
  'tabs.settings': 'Einstellungen',
  'tabs.inbox': 'Inbox',

  'age.now': 'jetzt',
  'age.justNow': 'gerade eben',
  'age.minutes': '{n} Min.',
  'age.hours': '{n} Std.',
  'age.days': '{n} T',
  'age.weeks': '{n} W',
  'age.ago': 'vor {relative}',
  'inbox.title': 'Inbox',
  'inbox.offline': 'notifi-Server nicht erreichbar. Verbindung prüfen und erneut versuchen.',
  'inbox.count': { one: '1 Benachrichtigung', other: '{n} Benachrichtigungen' },
  'inbox.unreadSummary': ' ungelesen · {total}',
  'inbox.filteredToKey': 'Gefiltert nach Schlüssel „{name}“.',
  'inbox.closeSearch': 'Suche schließen',
  'inbox.markAllAsRead': 'Alle als gelesen markieren',
  'inbox.filterByKey': 'Nach Schlüssel filtern',
  'inbox.allKeys': 'Alle Schlüssel',
  'inbox.refresh': 'Aktualisieren',
  'inbox.more': 'Mehr',
  'inbox.copyTitle': 'Titel kopieren',
  'inbox.copyMessage': 'Nachricht kopieren',
  'inbox.copyLink': 'Link kopieren',
  'inbox.seedSampleData': 'Beispieldaten erzeugen',
  'inbox.clearSampleData': 'Beispieldaten löschen',

  'inbox.bandToday': 'Heute',
  'inbox.bandYesterday': 'Gestern',
  'inbox.bandLabel': '{title}, {count}',

  'inbox.unread': 'Ungelesen',
  'inbox.critical': 'Kritisch',
  'inbox.linkTo': 'Link zu {host}',
  'inbox.deleteTitle': '„{title}“ löschen?',
  'inbox.deleteTitleFallback': 'Diese Benachrichtigung löschen?',
  'inbox.deleteMessage': 'Das kann nicht rückgängig gemacht werden.',

  'search.prompt': 'Benachrichtigungen durchsuchen',
  'search.matches': { one: '1 Treffer', other: '{n} Treffer' },
  'search.recent': 'Zuletzt',

  'message.notFound': 'Nachricht nicht gefunden',
  'message.notFoundDetail': 'Sie wurde möglicherweise auf diesem Gerät gelöscht.',
  'message.downloadImage': 'Bild herunterladen',
  'message.keyFallbackName': 'Schlüssel {id}',
  'message.sentWithKey': 'Gesendet mit Schlüssel {name}',
  'message.openKey': 'Gesendet mit Schlüssel {name}. Öffnen.',
  'message.viewImageFullScreen': 'Bild im Vollbild anzeigen',
  'message.shareLink': 'Link teilen',
  'message.imageFailedToLoad': 'Bild konnte nicht geladen werden',
  'message.imageHidden': 'Bild ausgeblendet',
  'message.imageHost': 'einem anderen Host',
  'message.imageLoadWarning': 'Beim Laden wird {host} kontaktiert.',
  'message.loadImage': 'Bild laden',
  'message.load': 'Laden',
  'message.imageBlocked': 'blockiert',
  'message.sourceHeader': 'Quelle',
  'keys.title': 'Schlüssel',
  'keys.newKey': 'Neuer Schlüssel',
  'keys.refreshFailed': 'Schlüssel konnten nicht aktualisiert werden. Letzte bekannte Liste wird angezeigt.',
  'keys.sectionActive': 'Aktiv',
  'keys.sectionRevoked': 'Widerrufen',
  'keys.intro':
    'Schlüssel zeigen, wer eine Nachricht gesendet hat. Verwende für jedes Skript einen eigenen Schlüssel. ' +
    'Der Standardschlüssel wurde bei der Einrichtung dieses Geräts erstellt.',
  'keys.aboutKeys': 'Über Schlüssel',
  'keys.sent': { one: '1 gesendet', other: '{n} gesendet' },
  'keys.rowLastUsed': 'genutzt {ago}',
  'keys.docsLink': 'API docs',
  'keys.chipDefault': 'Standard',
  'keys.chipRevoked': 'Widerrufen',
  'keys.chipCritical': 'Kritisch',
  'keys.rowLabel': 'Schlüssel, {name}, endet auf {suffix}',
  'keys.rowLabelRevoked': ', widerrufen',
  'keys.rowLabelCritical': ', Kritische Benachrichtigungen an',
  'keys.maskedValue': '{prefix}…',

  'keyDetail.notFound': 'Schlüssel nicht gefunden',
  'keyDetail.notFoundDetail': 'Er wurde möglicherweise auf einem anderen Gerät entfernt.',

  'keyDetail.criticalOn':
    'Sendungen von diesem Schlüssel, die es anfordern, ertönen auch im Stumm- und Fokusmodus. ' +
    'is_critical=1 zur Sendung hinzufügen.',
  'keyDetail.criticalTimeSensitive':
    'Sendungen von diesem Schlüssel, die es anfordern, durchbrechen den Fokus und bleiben auf dem Sperr' +
    'bildschirm. is_critical=1 zur Sendung hinzufügen. Sie ertönen nicht im Stummmodus. ' +
    'Dafür ist eine Berechtigung nötig, die Apple notifi noch nicht erteilt hat.',

  'keyDetail.copyKey': 'Schlüssel kopieren',
  'keyDetail.shareKey': 'Schlüssel teilen',
  'keyDetail.copyCurl': 'Curl kopieren',
  'keyDetail.examplesLink': 'Weitere Sendearten',
  'keyDetail.defaultKeyDetail':
    'notifi behält diesen auf deinem Gerät, sodass du ihn jederzeit erneut kopieren ' +
    'oder unten neu erzeugen kannst.',
  'keyDetail.shownOnceDetail':
    'Der Wert wurde einmal angezeigt, als du diesen Schlüssel erstellt hast. Er wird nicht auf dem Gerät gespeichert.',

  'keyDetail.sectionUsage': 'Nutzung',
  'keyDetail.fieldSent': 'Gesendet',
  'keyDetail.fieldCreated': 'Erstellt',
  'keyDetail.fieldLastUsed': 'Zuletzt genutzt',

  'keyDetail.sectionLinks': 'Links',
  'keyDetail.openAnyLink': 'Beliebige Links öffnen',
  'keyDetail.openAnyLinkDetail':
    'Aus, es öffnen nur https-Links. An, es öffnen auch andere Schemata, einschließlich solcher, die ' +
    'andere Apps auf diesem Gerät starten.',

  'keyDetail.sectionAlerts': 'Benachrichtigungen',
  'keyDetail.criticalAlerts': 'Kritische Benachrichtigungen',

  'keyDetail.revokedNotice': 'Dieser Schlüssel ist widerrufen und akzeptiert keine Sendungen mehr.',

  'keyDetail.sectionDanger': 'Gefahrenzone',
  'keyDetail.regenerate': 'Schlüssel neu erzeugen',
  'keyDetail.regenerating': 'Wird neu erzeugt…',
  'keyDetail.regenerateDetail':
    'Beim Neuerzeugen entsteht ein neuer Wert, der alte wird stillgelegt. Alles, was noch mit dem alten ' +
    'Wert sendet, wird abgelehnt.',
  'keyDetail.revoke': 'Schlüssel widerrufen',
  'keyDetail.revoking': 'Wird widerrufen…',
  'keyDetail.revokeDetail':
    'Das Widerrufen ist endgültig. Alles, was noch an diesen Schlüssel sendet, wird abgelehnt.',

  'keyDetail.revokeTitle': '„{name}“ widerrufen?',
  'keyDetail.revokeTitleFallback': 'Diesen Schlüssel widerrufen?',
  'keyDetail.revokeConfirm': 'Widerrufen',
  'keyDetail.revokeMessage': 'Alles, was noch daran sendet, wird abgelehnt.',

  'keyDetail.regenerateTitle': '„{name}“ neu erzeugen?',
  'keyDetail.regenerateTitleFallback': 'Diesen Schlüssel neu erzeugen?',
  'keyDetail.regenerateConfirm': 'Neu erzeugen',
  'keyDetail.regenerateMessage':
    'Der aktuelle Wert funktioniert sofort nicht mehr, und alles, was noch damit sendet, ' +
    'wird abgelehnt.',

  'keyDetail.regeneratedAnnouncement': 'Schlüssel neu erzeugt. Der alte Wert funktioniert nicht mehr.',
  'keyDetail.regenerateFailed': 'Schlüssel konnte nicht neu erzeugt werden. Verbindung prüfen und erneut versuchen.',
  'keyDetail.revokedAnnouncement': 'Schlüssel widerrufen.',
  'keyDetail.revokeFailed': 'Schlüssel konnte nicht widerrufen werden. Verbindung prüfen und erneut versuchen.',

  'keyDetail.criticalNotPermitted':
    'Kritische Benachrichtigungen sind für notifi in den Systemeinstellungen deaktiviert. Sie durchbrechen ' +
    'weiterhin den Fokus, ertönen aber nicht im Stummmodus.',
  'keyDetail.criticalChangeFailed':
    'Kritische Benachrichtigungen für diesen Schlüssel konnten nicht geändert werden. Verbindung prüfen und erneut versuchen.',

  'createKey.title': 'Neuer Schlüssel',
  'createKey.intro': 'Ein Name, den nur du siehst. Er erscheint in der Schlüsselliste und in Filtern.',
  'createKey.sectionName': 'Name',
  'createKey.namePrompt': 'z. B. Grafana-Alerts',
  'createKey.nameLabel': 'Schlüsselname',
  'createKey.charCount': '{n}/{max}',
  'createKey.nameReserved': '„default“ ist reserviert. Dein Gerät hat bereits einen.',
  'createKey.nameTaken': 'Ein Schlüssel mit diesem Namen ist bereits aktiv.',
  'createKey.create': 'Schlüssel erstellen',
  'createKey.creating': 'Wird erstellt…',

  'createKey.validationEmpty': 'Gib einen Namen für diesen Schlüssel ein.',
  'createKey.validationTooLong': 'Verwende höchstens 64 Zeichen.',
  'createKey.validationReserved': 'Wähle einen anderen Namen. „default“ ist der Schlüssel deines Geräts.',
  'createKey.validationTaken': 'Wähle einen anderen Namen. Einer deiner aktiven Schlüssel hat diesen bereits.',
  'createKey.createFailed': 'Schlüssel konnte nicht erstellt werden. Verbindung prüfen und erneut versuchen.',

  'createKey.revealTitle': 'Kopiere deinen Schlüssel jetzt',
  'createKey.revealDetail': 'Er wird nicht noch einmal angezeigt.',
  'createKey.revealLabel': 'Dein neuer Schlüssel',
  'createKey.revealWarning':
    'Behandle ihn wie ein Passwort. Falls du ihn verlierst, widerrufe den Schlüssel und erstelle einen neuen.',

  'createKey.leaveTitle': 'Noch nicht kopiert?',
  'createKey.leaveCopyAndClose': 'Kopieren und schließen',
  'createKey.leaveCloseAndRevoke': 'Schließen und widerrufen',
  'createKey.leaveMessage': 'Dieser Schlüssel wird nie wieder angezeigt.',

  'settings.title': 'Einstellungen',

  'settings.sectionPermissions': 'Berechtigungen',
  'settings.permission': 'Berechtigung',
  'settings.openSystemSettings': 'Systemeinstellungen öffnen',

  'settings.permissionEnabled': 'Aktiviert',
  'settings.permissionOff': 'Aus',
  'settings.permissionProvisional': 'Vorläufig',
  'settings.permissionEphemeral': 'Flüchtig',
  'settings.delivery': 'Zustellung',
  'settings.deliveryBroken': 'Kein Push',
  'settings.deliveryBrokenDetail':
    'Letzte Nachrichten kamen ohne Benachrichtigung dahinter an. Benachrichtigungen '
    + 'erreichen dieses Gerät nicht; Nachrichten kommen weiterhin über die Live-'
    + 'Verbindung an sowie sobald die App geöffnet oder aktualisiert wird.',
  'settings.permissionNotSet': 'Nicht festgelegt',
  'settings.permissionUnknown': 'Unbekannt',

  'settings.sectionAppearance': 'Erscheinungsbild',
  'settings.theme': 'Design',
  'settings.themeDark': 'Dunkel',
  'settings.themeLight': 'Hell',

  'settings.loadImages': 'Bilder automatisch laden',
  'settings.loadImagesDetail':
    'Ruft jedes Bild ab, sobald die Nachricht ankommt, was dem Host deine IP-Adresse verrät. ' +
    'Aus, Bilder laden erst bei Antippen.',

  'settings.strictSend': 'Ungültige Sendungen ablehnen',
  'settings.strictSendDetail':
    'Gibt 422 invalid_content zurück und speichert nichts, wenn ein Titel oder eine Nachricht zu lang ist ' +
    'oder eine Bild-URL die Validierung nicht besteht. Aus, /send kürzt oder verwirft das Feld und ' +
    'gibt 202 mit einem warnings-Array zurück.',
  'settings.strictSendFailed': 'PATCH /devices/settings fehlgeschlagen. Verbindung prüfen und erneut versuchen.',

  'settings.testTitle': 'Testbenachrichtigung',
  'settings.testBody': 'Wenn du das lesen kannst, funktioniert notifi.',

  'settings.sectionSupport': 'Support',
  'settings.sectionApplication': 'Anwendung',
  'settings.sectionAbout': 'Über',
  'settings.version': 'Version',
  'settings.openAtLogin': 'Bei Anmeldung öffnen',
  'settings.openAtLoginDetail': 'Startet notifi bei der Anmeldung an diesem Mac in der Menüleiste.',
  'settings.automaticUpdates': 'Automatische Updates',
  'settings.automaticUpdatesDetail': 'Sucht im Hintergrund nach neuen Versionen.',
  'settings.checkForUpdates': 'Nach Updates suchen',
  'settings.support': 'Problem melden',
  'settings.feedback': 'Feedback',
  'settings.privacyPolicy': 'Datenschutzerklärung',
  'settings.website': 'notifi.it',

  'empty.sampleTitle': 'Hello World',
  'empty.sampleMessage': 'Das kam von dem Befehl, den du gerade ausgeführt hast.',

  'empty.title': 'Noch nichts hier',
  'empty.detail': 'Sende deine erste Benachrichtigung, und sie landet hier.',

  'empty.stepAllow': 'Benachrichtigungen erlauben',
  'empty.notificationsOn': 'Benachrichtigungen sind an.',
  'empty.enableNotifications': 'Benachrichtigungen aktivieren',

  'empty.stepSend': 'Eine senden',
  'empty.sendTest': 'Test senden',
  'empty.sending': 'Wird gesendet…',
  'empty.sent': 'Gesendet. Sie kommt gleich hier und auf deinem Sperrbildschirm an.',
  'empty.sentDetail':
    'Sie kommt hier und auf deinem Sperrbildschirm an. Erstelle unter Schlüssel weitere, um Quellen zu trennen.',
  'empty.sendFailed': 'Senden fehlgeschlagen. Verbindung prüfen und erneut versuchen.',

  'empty.makingKey': 'Dein Schlüssel wird erstellt…',
  'empty.makeKeyFailed': 'Schlüssel konnte nicht erstellt werden. Verbindung prüfen und erneut versuchen.',

  'empty.stepLabel': 'Schritt {n}. {title}.',
  'empty.stepDone': ' Fertig.',

  'components.clearSearch': 'Suche löschen',
  'components.noMatches': 'Keine Treffer',
  'components.noMatchesDetail': 'Mit diesem Filter gibt es hier nichts.',
  'components.noMatchesQuery': 'Nichts gefunden für „{query}“.',
  'components.errorLabel': 'Fehler. {message}',
  'components.backTo': 'Zurück zu {label}',
  'components.createKey': 'Schlüssel erstellen',
  'components.wordmark': 'notifi',

  'identity.title': 'notifi kann nicht entsperrt werden',
  'identity.detail':
    'notifi konnte seinen Identitätsschlüssel nicht aus dem Schlüsselbund lesen. Das behebt sich meist von selbst, sobald das ' +
    'Gerät entsperrt wurde. Deine Nachrichten und Sendeschlüssel sind davon nicht betroffen.',

  'unsupported.title': 'Nicht unterstützter Mac',
  'unsupported.detail':
    'notifi benötigt einen Mac mit Apple Silicon oder einem T2-Chip. Dieser Mac hat keine Secure Enclave, ' +
    'die notifi zum Schutz deines Identitätsschlüssels verwendet.',

  'restore.title': 'Das sieht nach einem neuen Gerät aus',
  'restore.detail':
    'Deine alten Nachrichten wurden aus einem Backup wiederhergestellt, deine Schlüssel jedoch nicht. Schlüssel sind an das ' +
    'Gerät gebunden, auf dem sie erstellt wurden, und können nicht übertragen werden. Alles, was noch an deine alten Schlüssel sendet, ' +
    'wird jetzt abgelehnt. Erstelle neue Schlüssel, um weiter Benachrichtigungen zu erhalten.',

  'clientErrors.unauthorized': 'Dieser Schlüssel wird nicht mehr akzeptiert. Erstelle einen neuen unter Schlüssel.',
  'clientErrors.notFound': 'Das ist nicht mehr auf dem Server. Aktualisieren und erneut versuchen.',
  'clientErrors.rateLimited': 'Gerade zu viele Anfragen. In einem Moment erneut versuchen.',
  'clientErrors.server': 'Der Server hat gerade Probleme. In einem Moment erneut versuchen.',
  'clientErrors.generic': 'Die Anfrage kam nicht durch. Erneut versuchen.',
  'clientErrors.transport': 'Server nicht erreichbar. Verbindung prüfen und erneut versuchen.',
  'clientErrors.decoding': 'Der Server hat etwas Unerwartetes zurückgegeben. In einem Moment erneut versuchen.',
};
