import type { Translation } from '../types.js';

export const fr: Translation = {
  'api.notFound': 'Introuvable.',
  'api.unexpected': 'Erreur inattendue.',

  'api.rateLimitedIP': 'Trop de requêtes depuis cette adresse IP.',
  'api.rateLimitedAccount': 'Limite de débit dépassée. Trop de notifications cette heure-ci.',

  'api.badSignature': 'Signature de requête invalide.',
  'api.staleTimestamp': "L’horodatage de la requête est hors de la fenêtre autorisée.",

  'api.unknownDevice': "L’appareil n’est pas enregistré.",
  'api.unknownKey': 'Clé inconnue ou révoquée.',
  'api.keyPaused':
    "Cette clé est en pause. Elle n’accepte aucun envoi tant qu’elle n’est pas réactivée dans l’application.",
  'api.keyNotFound': 'Clé introuvable.',
  'api.activeKeyLimit': 'Limite de clés actives atteinte.',

  'api.invalidDeviceBody': "Corps d’enregistrement de l’appareil invalide.",
  'api.publicKeyMismatch': 'public_key doit correspondre à la clé publique de signature.',
  'api.invalidEncryptionKey': "encryption_public_key n’est pas un point P-256 valide.",
  'api.invalidCreateKeyBody': 'Corps de création de clé invalide.',
  'api.invalidUpdateKeyBody': 'Corps de mise à jour de clé invalide.',
  'api.invalidDeviceSettingsBody': "Corps des réglages de l’appareil invalide.",
  'api.invalidHistoryQuery': "Requête d’historique invalide.",
  'api.invalidSendParams': "Paramètres d’envoi invalides.",
  'api.occurredAtTooFuture': 'occurred_at est trop loin dans le futur.',
  'api.criticalNotAllowed':
    'Envoyée comme notification normale : les alertes critiques sont désactivées pour cette clé.',
  'api.titleCropped': 'Envoyé avec un titre raccourci : il dépassait {max} caractères.',
  'api.messageCropped': 'Envoyé avec une notification raccourcie : elle dépassait {max} caractères.',
  'api.strictContentRejected':
    "Non envoyé. Cet appareil est configuré pour refuser une notification qu’il ne peut pas livrer telle quelle.",


  'push.fallbackTitle': 'notifi',
  'push.fallbackBody': 'Ouvrez notifi pour voir',
  'push.actionOpenLink': 'Ouvrir le lien',
  'push.actionMarkAsRead': 'Marquer comme lu',
  'push.summaryFormat': '%%u de plus de {name}',

  'common.cancel': 'Annuler',
  'common.close': 'Fermer',
  'common.delete': 'Supprimer',
  'common.done': 'Terminé',
  'common.copy': 'Copier',
  'common.copied': 'Copié',
  'common.share': 'Partager',
  'common.clear': 'Effacer',
  'common.search': 'Rechercher',
  'common.tryAgain': 'Réessayer',
  'common.continueAction': 'Continuer',
  'common.quit': 'Quitter',
  'common.markAsRead': 'Marquer comme lu',
  'common.markAsUnread': 'Marquer comme non lu',
  'common.openLink': 'Ouvrir le lien',
  'common.never': 'Jamais',
  'common.expand': 'Déplier',
  'common.collapse': 'Replier',

  'tabs.keys': 'Clés',
  'tabs.settings': 'Réglages',
  'tabs.inbox': 'Inbox',

  'age.now': 'à l’instant',
  'age.justNow': 'à l’instant',
  'age.minutes': '{n} min',
  'age.hours': '{n} h',
  'age.days': '{n} j',
  'age.weeks': '{n} sem.',
  'age.ago': 'il y a {relative}',
  'inbox.title': 'Inbox',
  'inbox.offline':
    'Impossible de joindre les serveurs notifi. Vérifiez votre connexion et réessayez.',
  'inbox.count': { one: '1 notification', other: '{n} notifications' },
  'inbox.filteredToKey': 'Filtré sur la clé « {name} ».',
  'inbox.closeSearch': 'Fermer la recherche',
  'inbox.markAllAsRead': 'Tout marquer comme lu',
  'inbox.filterByKey': 'Filtrer par clé',
  'inbox.allKeys': 'Toutes les clés',
  'inbox.refresh': 'Actualiser',
  'inbox.more': 'Plus',
  'inbox.copyTitle': 'Copier le titre',
  'inbox.copyMessage': 'Copier la notification',
  'inbox.copyLink': 'Copier le lien',
  'inbox.seedSampleData': "Générer des données d’exemple",
  'inbox.clearSampleData': "Effacer les données d’exemple",

  'inbox.bandToday': "Aujourd’hui",
  'inbox.bandYesterday': 'Hier',
  'inbox.bandLabel': '{title}, {count}',

  'inbox.unread': 'Non lu',
  'inbox.critical': 'Critique',
  'inbox.linkTo': 'Lien vers {host}',
  'inbox.deleteTitle': 'Supprimer « {title} » ?',
  'inbox.deleteTitleFallback': 'Supprimer cette notification ?',
  'inbox.deleteMessage': 'Cette action est irréversible.',

  'search.prompt': 'Rechercher dans Inbox',
  'search.matches': { one: '1 résultat', other: '{n} résultats' },
  'search.recent': 'Récents',

  'message.notFound': 'Notification introuvable',
  'message.notFoundDetail': 'Elle a peut-être été supprimée sur cet appareil.',
  'message.downloadImage': "Télécharger l’image",
  'message.keyFallbackName': 'Clé {id}',
  'message.sentWithKey': 'Envoyé avec la clé {name}',
  'message.openKey': 'Envoyé avec la clé {name}. Ouvrir.',
  'message.viewImageFullScreen': "Voir l’image en plein écran",
  'message.shareLink': 'Partager le lien',
  'message.imageFailedToLoad': "Échec du chargement de l’image",
  'message.imageHidden': 'Image masquée',
  'message.imageHost': 'un autre hôte',
  'message.imageLoadWarning': 'Le charger contacte {host}.',
  'message.loadImage': "Charger l’image",
  'message.load': 'Charger',
  'message.imageBlocked': 'bloquée',
  'message.sourceHeader': 'Source',
  'keys.title': 'Clés',
  'keys.newKey': 'Nouvelle clé',
  'keys.refreshFailed': "Impossible d’actualiser les clés. Affichage de la dernière liste connue.",
  'keys.sectionActive': 'Actives',
  'keys.sectionRevoked': 'Révoquées',
  'keys.intro':
    'Les clés identifient qui a envoyé une notification. Utilisez une clé différente pour chaque script. ' +
    'La clé par défaut a été créée lors de la configuration de cet appareil.',
  'keys.aboutKeys': 'À propos des clés',
  'keys.sent': { one: '1 envoi', other: '{n} envois' },
  'keys.rowLastUsed': 'utilisée {ago}',
  'keys.docsLink': 'API docs',
  'keys.chipDefault': 'Par défaut',
  'keys.chipRevoked': 'Révoquée',
  'keys.chipPaused': 'En pause',
  'keys.chipCritical': 'Critique',
  'keys.rowLabel': 'Clé, {name}, se termine par {suffix}',
  'keys.rowLabelRevoked': ', révoquée',
  'keys.rowLabelPaused': ', en pause',
  'keys.rowLabelCritical': ', alertes critiques activées',
  'keys.maskedValue': '{prefix}…',

  'keyDetail.notFound': 'Clé introuvable',
  'keyDetail.notFoundDetail': 'Elle a peut-être été supprimée sur un autre appareil.',

  'keyDetail.criticalOn':
    'Les envois de cette clé qui le demandent sonneront malgré le mode silencieux et Focus. ' +
    'Ajoutez is_critical=1 à l’envoi.',
  'keyDetail.criticalTimeSensitive':
    'Les envois de cette clé qui le demandent franchissent Focus et restent sur l’écran ' +
    'verrouillé. Ajoutez is_critical=1 à l’envoi. Ils ne sonneront pas malgré le mode ' +
    'silencieux. Cela nécessite une habilitation qu’Apple n’a pas encore accordée à notifi.',

  'keyDetail.copyKey': 'Copier la clé',
  'keyDetail.shareKey': 'Partager la clé',
  'keyDetail.copyCurl': 'Copier curl',
  'keyDetail.examplesLink': 'Docs',
  'keyDetail.defaultKeyDetail':
    'notifi conserve celle-ci sur votre appareil, vous pouvez donc la copier à nouveau ' +
    'quand vous en avez besoin, ou la régénérer ci-dessous.',
  'keyDetail.shownOnceDetail':
    "La valeur n’a été affichée qu’une fois, à la création de cette clé. Elle n’est pas stockée sur l’appareil.",

  'keyDetail.sectionUsage': 'Utilisation',
  'keyDetail.fieldSent': 'Envois',
  'keyDetail.fieldCreated': 'Créée le',
  'keyDetail.fieldLastUsed': 'Dernière utilisation',

  'keyDetail.openAnyLink': "Ouvrir n’importe quel lien",
  'keyDetail.openAnyLinkDetail':
    'Désactivé, seuls les liens https s’ouvrent. Activé, d’autres schémas s’ouvrent aussi, ' +
    'y compris ceux qui lancent d’autres applications sur cet appareil.',

  'keyDetail.criticalAlerts': 'Alertes critiques',

  'keyDetail.paused': 'En pause',
  'keyDetail.pausedDetail':
    "Activé, cette clé n’accepte rien et aucune notification n’est délivrée. Désactivé, " +
    "elle envoie comme avant. La valeur ne change pas, rien n’a donc à être mis à jour " +
    "là où elle est utilisée.",
  'keyDetail.pauseFailed':
    'Impossible de modifier la pause de cette clé. Vérifiez votre connexion et réessayez.',
  'keyDetail.pausedAnnouncement': 'Clé en pause.',
  'keyDetail.resumedAnnouncement': 'Clé réactivée.',
  'keyDetail.pausedNotice':
    "Cette clé est en pause. Tout ce qui envoie avec elle sera rejeté jusqu’à ce que vous la réactiviez.",

  'keyDetail.sectionName': 'Nom',
  'keyDetail.rename': 'Renommer la clé',
  'keyDetail.renaming': 'Renommage…',
  'keyDetail.renameDetail':
    "Le nom n’est affiché que sur cet appareil. La clé elle-même ne change pas, rien de ce " +
    "qui envoie avec elle n’a donc à être mis à jour.",
  'keyDetail.renameTitle': 'Renommer « {name} »',
  'keyDetail.renameConfirm': 'Renommer',
  'keyDetail.renameMessage':
    'Un nom que vous seul voyez. Il apparaît dans la liste des clés et dans les filtres.',
  'keyDetail.renamedAnnouncement': 'Clé renommée.',
  'keyDetail.renameFailed':
    'Impossible de renommer la clé. Vérifiez votre connexion et réessayez.',
  'keyDetail.renameDefaultDetail':
    "La clé par défaut conserve son nom. L’application la retrouve par ce nom sur cet appareil.",

  'keyDetail.revokedNotice': "Cette clé est révoquée et n’accepte plus d’envois.",

  'keyDetail.sectionDanger': 'Zone de danger',
  'keyDetail.regenerate': 'Régénérer la clé',
  'keyDetail.regenerating': 'Régénération…',
  'keyDetail.regenerateDetail':
    "Régénérer émet une nouvelle valeur et retire l’ancienne. Tout ce qui envoie encore " +
    "avec l’ancienne valeur sera rejeté.",
  'keyDetail.revoke': 'Révoquer la clé',
  'keyDetail.revoking': 'Révocation…',
  'keyDetail.revokeDetail':
    'La révocation est définitive. Tout ce qui envoie encore à cette clé sera rejeté.',

  'keyDetail.revokeTitle': 'Révoquer « {name} » ?',
  'keyDetail.revokeTitleFallback': 'Révoquer cette clé ?',
  'keyDetail.revokeConfirm': 'Révoquer',
  'keyDetail.revokeMessage': 'Tout ce qui envoie encore vers elle sera rejeté.',

  'keyDetail.regenerateTitle': 'Régénérer « {name} » ?',
  'keyDetail.regenerateTitleFallback': 'Régénérer cette clé ?',
  'keyDetail.regenerateConfirm': 'Régénérer',
  'keyDetail.regenerateMessage':
    "La valeur actuelle cesse de fonctionner immédiatement, et tout ce qui envoie encore " +
    "avec elle sera rejeté.",

  'keyDetail.regeneratedAnnouncement': "Clé régénérée. L’ancienne valeur ne fonctionne plus.",
  'keyDetail.regenerateFailed':
    "Impossible de régénérer la clé. Vérifiez votre connexion et réessayez.",
  'keyDetail.revokedAnnouncement': 'Clé révoquée.',
  'keyDetail.revokeFailed': "Impossible de révoquer la clé. Vérifiez votre connexion et réessayez.",

  'keyDetail.criticalNotPermitted':
    'Les alertes critiques sont désactivées pour notifi dans les réglages système. Elles ' +
    'franchiront quand même Focus, mais ne sonneront pas malgré le mode silencieux.',
  'keyDetail.criticalChangeFailed':
    "Impossible de modifier les alertes critiques pour cette clé. Vérifiez votre connexion et réessayez.",

  'createKey.title': 'Nouvelle clé',
  'createKey.intro':
    'Un nom que vous seul voyez. Il apparaît dans la liste des clés et dans les filtres.',
  'createKey.sectionName': 'Nom',
  'createKey.namePrompt': 'ex. Alertes Grafana',
  'createKey.nameLabel': 'Nom de la clé',
  'createKey.charCount': '{n}/{max}',
  'createKey.nameReserved': '« default » est réservé. Votre appareil en a déjà une.',
  'createKey.nameTaken': 'Une clé portant ce nom est déjà active.',
  'createKey.create': 'Créer la clé',
  'createKey.creating': 'Création…',

  'createKey.validationEmpty': 'Entrez un nom pour cette clé.',
  'createKey.validationTooLong': 'Utilisez 64 caractères ou moins.',
  'createKey.validationReserved': 'Choisissez un autre nom. « default » est la clé de votre appareil.',
  'createKey.validationTaken': "Choisissez un autre nom. Une de vos clés actives porte déjà celui-ci.",
  'createKey.createFailed': "Impossible de créer la clé. Vérifiez votre connexion et réessayez.",

  'createKey.revealTitle': 'Copiez votre clé maintenant',
  'createKey.revealDetail': 'Elle ne sera plus affichée.',
  'createKey.revealLabel': 'Votre nouvelle clé',
  'createKey.revealWarning':
    'Traitez-la comme un mot de passe. Si vous la perdez, révoquez la clé et créez-en une nouvelle.',

  'createKey.leaveTitle': "Vous ne l’avez pas copiée ?",
  'createKey.leaveCopyAndClose': 'Copier et fermer',
  'createKey.leaveCloseAndRevoke': 'Fermer et révoquer',
  'createKey.leaveMessage': 'Cette clé ne sera plus jamais affichée.',

  'settings.title': 'Réglages',

  'settings.sectionPermissions': 'Autorisations',
  'settings.permission': 'Autorisation',
  'settings.openSystemSettings': 'Ouvrir les réglages système',

  'settings.permissionEnabled': 'Activée',
  'settings.permissionOff': 'Désactivée',
  'settings.permissionProvisional': 'Provisoire',
  'settings.permissionEphemeral': 'Éphémère',
  'settings.permissionNotSet': 'Non défini',
  'settings.permissionUnknown': 'Inconnue',

  'settings.theme': 'Thème',
  'settings.themeDark': 'Sombre',
  'settings.themeLight': 'Clair',
  'settings.themeSystem': 'Système',

  'settings.loadImages': 'Charger les images automatiquement',
  'settings.loadImagesDetail':
    "Récupère chaque image dès l’arrivée de la notification, ce qui révèle votre adresse IP à son " +
    "hôte. Désactivé, les images ne se chargent qu’au toucher.",

  'settings.strictSend': 'Rejeter les envois invalides',
  'settings.strictSendDetail':
    "Renvoie 422 invalid_content et ne stocke rien lorsqu’un titre ou un corps dépasse la " +
    "longueur autorisée. Désactivé, /send raccourcit le champ et renvoie 202 avec un tableau warnings.",
  'settings.strictSendFailed': 'Échec de PATCH /devices/settings. Vérifiez votre connexion et réessayez.',

  'settings.testTitle': 'Hello from notifi',
  'settings.testBody': 'Votre première notification.',

  'settings.macApp': 'Télécharger pour Mac',

  'settings.iosApp': "Télécharger dans l’App Store",

  'settings.sectionSupport': 'Assistance',
  'settings.sectionApplication': 'Application',
  'settings.sectionAbout': 'À propos',
  'settings.version': 'Version',
  'settings.openAtLogin': "Ouvrir à l’ouverture de session",
  'settings.openAtLoginDetail':
    "Démarre notifi dans la barre des menus lorsque vous ouvrez une session sur ce Mac.",
  'settings.installUpdatesAutomatically': 'Installer les mises à jour automatiquement',
  'settings.installUpdatesAutomaticallyDetail':
    "Télécharge et installe les nouvelles versions sans demander. notifi redémarre lorsqu’il se met à jour.",
  'settings.checkForUpdates': 'Rechercher des mises à jour',
  'settings.deleteAll': 'Supprimer toutes les notifications',
  'settings.deleteAllTitle': 'Supprimer toutes les notifications ?',
  'settings.deleteAllConfirm': 'Tout supprimer',
  'settings.deleteAllMessage': 'Cette action est irréversible.',
  'settings.support': 'Signaler un problème',
  'settings.feedback': 'Avis',
  'settings.privacyPolicy': 'Politique de confidentialité',
  'settings.website': 'notifi.it',

  'empty.sampleTitle': 'Hello from notifi',
  'empty.sampleMessage': 'Votre première notification.',

  'empty.title': 'Rien pour le moment',
  'empty.detail': 'Envoyez votre première notification et elle apparaîtra ici.',

  'empty.stepAllow': 'Autoriser les notifications',
  'empty.notificationsOn': 'Les notifications sont activées.',
  'empty.enableNotifications': 'Activer les notifications',

  'empty.stepSend': 'En envoyer une',
  'empty.sendTest': 'Envoyer un test',
  'empty.sending': 'Envoi…',
  'empty.sent': 'Envoyée. Elle arrive ici et sur votre écran verrouillé dans un instant.',
  'empty.sendFailed': "Échec de l’envoi. Vérifiez votre connexion et réessayez.",

  'empty.makingKey': 'Création de votre clé…',
  'empty.makeKeyFailed': "Impossible de créer une clé. Vérifiez votre connexion et réessayez.",

  'empty.stepLabel': 'Étape {n}. {title}.',
  'empty.stepDone': ' Terminée.',

  'components.clearSearch': 'Effacer la recherche',
  'components.noMatches': 'Aucun résultat',
  'components.noMatchesDetail': 'Rien ici avec ce filtre.',
  'components.noMatchesQuery': 'Aucun résultat pour « {query} ».',
  'components.errorLabel': 'Erreur. {message}',
  'components.backTo': 'Retour à {label}',
  'components.createKey': 'Créer une clé',

  'identity.title': 'Impossible de déverrouiller notifi',
  'identity.detail':
    "notifi n’a pas pu lire sa clé d’identité dans le trousseau. Cela se résout généralement " +
    "une fois l’appareil déverrouillé. Vos notifications et clés d’envoi ne sont pas affectées.",

  'unsupported.title': 'Mac non pris en charge',
  'unsupported.detail':
    "notifi nécessite un Mac avec puce Apple silicon ou puce T2. Ce Mac n’a pas d’Enclave " +
    "sécurisée, que notifi utilise pour protéger votre clé d’identité.",

  'store.name': 'notifi : notifications push',
  'store.subtitle': 'Pour scripts et serveurs',
  'store.promotionalText':
    'Une requête HTTP, et la notification arrive sur votre iPhone ou Mac. Chiffré avec ' +
    'votre clé publique, donc nous ne pouvons pas la lire. Pas de compte.',
  'store.keywords':
    'webhook,api,avertir,alerte,auto,hébergé,cron,curl,cli,devops,homelab,ssh,docker,' +
    'monitor',
  'store.description':
    'Notifications push pour vos scripts et serveurs.\n\n' +
    "Créez une clé d’envoi et envoyez un titre et un corps à notifi.it en une seule " +
    'requête HTTP. La notification arrive sur votre iPhone ou Mac. Tout ce qui peut faire ' +
    'une requête HTTP peut en envoyer une, par exemple un script shell, une tâche cron, un ' +
    'pipeline CI.\n\n' +
    'https://notifi.it/send?title=hello+world\n\n' +
    "CE QUE CONTIENT UNE NOTIFICATION\n" +
    'Un titre, un corps, une image et un lien. Le corps est en Markdown : titres, listes, ' +
    "citations, liens et blocs de code sont rendus sur l’appareil.\n\n" +
    'CHIFFRÉ\n' +
    'Votre appareil détient la seule clé privée. Le contenu des notifications est chiffré avec ' +
    "votre clé publique à l’ingestion, si bien que nous ne pouvons pas lire vos notifications. " +
    "Chaque notification est supprimée du serveur une fois que votre appareil l’a confirmée.\n\n" +
    'PAS DE COMPTE\n' +
    "Pas d’inscription, pas de connexion, pas de liaison d’appareil. L’application génère " +
    "une clé d’envoi au premier lancement. Les clés peuvent être renommées, suspendues et " +
    'révoquées par source.\n\n' +
    'ALERTES URGENTES\n' +
    'Marquez une clé comme urgente et ses notifications franchissent Focus et arrivent sur ' +
    "l'écran verrouillé.\n",
  'store.releaseNotes': 'Bug fixes and performance improvements.\n',
  'store.shotInboxTitle': 'Une requête.\nDroit dans votre poche.',
  'store.shotInboxTitleIpad': 'Une requête.\nDroit sur vos appareils.',
  'store.shotInboxBody':
    'Notifications push pour vos scripts et serveurs. Une requête HTTP vers notifi.it et ' +
    'elle arrive un instant plus tard. Pas de compte.',
  'store.shotMessageTitle': 'Images, liens,\nMarkdown.',
  'store.shotMessageBody':
    'Un titre, un corps, une image et un lien. Titres, listes, citations et blocs de code ' +
    'sont rendus sur l\'appareil. Chiffré avec votre clé publique, nous ne pouvons donc pas ' +
    'lire vos notifications.',
  'store.shotKeysTitle': 'Une clé\npar source.',
  'store.shotKeysBody':
    "Donnez une clé au bot de déploiement et une autre à la sonnette. Révoquez-en une, les " +
    "autres continuent de fonctionner. Chaque clé porte son propre nombre d’envois, sans " +
    'aucun compte à créer au préalable.',

  'restore.title': 'Cela ressemble à un nouvel appareil',
  'restore.detail':
    'Vos anciennes notifications ont été restaurées depuis une sauvegarde, mais pas vos clés. Les ' +
    "clés sont liées à l’appareil sur lequel elles ont été créées et ne peuvent pas être " +
    "déplacées. Tout ce qui envoie encore vers vos anciennes clés sera désormais rejeté. " +
    'Créez de nouvelles clés pour continuer à recevoir des notifications.',

  'clientErrors.unauthorized': "Cette clé n’est plus acceptée. Créez-en une nouvelle dans Clés.",
  'clientErrors.notFound': "Ce n’est plus sur le serveur. Actualisez et réessayez.",
  'clientErrors.rateLimited': 'Trop de requêtes à l’instant. Réessayez dans un moment.',
  'clientErrors.server': 'Le serveur rencontre un problème. Réessayez dans un moment.',
  'clientErrors.generic': "La requête n’a pas abouti. Réessayez.",
  'clientErrors.transport': "Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.",
  'clientErrors.decoding': 'Le serveur a renvoyé une réponse inattendue. Réessayez dans un moment.',
};
