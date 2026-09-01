import type { Translation } from '../types.js';

export const it: Translation = {
  'api.notFound': 'Non trovato.',
  'api.unexpected': 'Errore imprevisto.',

  'api.rateLimitedIP': 'Troppe richieste da questo IP.',
  'api.rateLimitedAccount': 'Limite superato. Troppe notifiche in questa ora.',

  'api.badSignature': 'Firma della richiesta non valida.',
  'api.staleTimestamp': 'Il timestamp della richiesta è fuori dalla finestra consentita.',

  'api.unknownDevice': 'Il dispositivo non è registrato.',
  'api.unknownKey': 'Chiave sconosciuta o revocata.',
  'api.keyNotFound': 'Chiave non trovata.',
  'api.activeKeyLimit': 'Limite di chiavi attive raggiunto.',

  'api.invalidDeviceBody': 'Corpo di registrazione del dispositivo non valido.',
  'api.publicKeyMismatch': 'public_key deve corrispondere alla chiave pubblica di firma.',
  'api.invalidEncryptionKey': 'encryption_public_key non è un punto P-256 valido.',
  'api.invalidCreateKeyBody': 'Corpo di creazione chiave non valido.',
  'api.invalidUpdateKeyBody': 'Corpo di aggiornamento chiave non valido.',
  'api.invalidDeviceSettingsBody': 'Corpo delle impostazioni del dispositivo non valido.',
  'api.invalidHistoryQuery': 'Query della cronologia non valida.',
  'api.invalidSendParams': 'Parametri di invio non validi.',
  'api.occurredAtTooFuture': 'occurred_at è troppo lontano nel futuro.',
  'api.criticalNotAllowed':
    'Inviata come notifica normale: gli avvisi critici sono disattivati per questa chiave.',
  'api.titleCropped': 'Inviata con un titolo abbreviato: superava {max} caratteri.',
  'api.messageCropped': 'Inviata con una notifica abbreviata: superava {max} caratteri.',
  'api.strictContentRejected':
    'Non inviata. Questo dispositivo è impostato per rifiutare una notifica che non può consegnare così com\'è scritta.',


  'push.fallbackTitle': 'notifi',
  'push.fallbackBody': 'Apri notifi per visualizzare',
  'push.actionOpenLink': 'Apri link',
  'push.actionMarkAsRead': 'Segna come letto',
  'push.summaryFormat': '%%u altre da {name}',

  'common.cancel': 'Annulla',
  'common.close': 'Chiudi',
  'common.delete': 'Elimina',
  'common.done': 'Fatto',
  'common.copy': 'Copia',
  'common.copied': 'Copiato',
  'common.share': 'Condividi',
  'common.clear': 'Cancella',
  'common.search': 'Cerca',
  'common.tryAgain': 'Riprova',
  'common.continueAction': 'Continua',
  'common.quit': 'Esci',
  'common.markAsRead': 'Segna come letto',
  'common.markAsUnread': 'Segna come non letto',
  'common.openLink': 'Apri link',
  'common.never': 'Mai',
  'common.expand': 'Espandi',
  'common.collapse': 'Comprimi',

  'tabs.keys': 'Chiavi',
  'tabs.settings': 'Impostazioni',
  'tabs.inbox': 'Inbox',

  'age.now': 'ora',
  'age.justNow': 'proprio ora',
  'age.minutes': '{n} min',
  'age.hours': '{n} h',
  'age.days': '{n} g',
  'age.weeks': '{n} sett',
  'age.ago': '{relative} fa',
  'inbox.title': 'Inbox',
  'inbox.offline': 'Impossibile raggiungere i server notifi. Controlla la connessione e riprova.',
  'inbox.count': { one: '1 notifica', other: '{n} notifiche' },
  'inbox.filteredToKey': 'Filtrato sulla chiave “{name}”.',
  'inbox.closeSearch': 'Chiudi ricerca',
  'inbox.markAllAsRead': 'Segna tutte come lette',
  'inbox.filterByKey': 'Filtra per chiave',
  'inbox.allKeys': 'Tutte le chiavi',
  'inbox.refresh': 'Aggiorna',
  'inbox.more': 'Altro',
  'inbox.copyTitle': 'Copia titolo',
  'inbox.copyMessage': 'Copia notifica',
  'inbox.copyLink': 'Copia link',
  'inbox.seedSampleData': 'Genera dati di esempio',
  'inbox.clearSampleData': 'Cancella dati di esempio',

  'inbox.bandToday': 'Oggi',
  'inbox.bandYesterday': 'Ieri',
  'inbox.bandLabel': '{title}, {count}',

  'inbox.unread': 'Non letta',
  'inbox.critical': 'Critica',
  'inbox.hasImage': 'Contiene un’immagine',
  'inbox.offlineBadge': 'Offline',
  'inbox.linkTo': 'Link a {host}',
  'inbox.deleteTitle': 'Eliminare “{title}”?',
  'inbox.deleteTitleFallback': 'Eliminare questa notifica?',
  'inbox.deleteMessage': "Questa azione non può essere annullata.",

  'search.prompt': 'Cerca in Inbox',
  'search.matches': { one: '1 risultato', other: '{n} risultati' },
  'search.recent': 'Recenti',

  'message.notFound': 'Notifica non trovata',
  'message.notFoundDetail': 'Potrebbe essere stato eliminato su questo dispositivo.',
  'message.downloadImage': 'Scarica immagine',
  'message.keyFallbackName': 'Chiave {id}',
  'message.sentWithKey': 'Inviato con la chiave {name}',
  'message.openKey': 'Inviato con la chiave {name}. Aprila.',
  'message.viewImageFullScreen': 'Visualizza immagine a schermo intero',
  'message.shareLink': 'Condividi link',
  'message.imageFailedToLoad': "Caricamento dell’immagine non riuscito",
  'message.imageHidden': 'Immagine nascosta',
  'message.imageHost': 'un altro host',
  'message.imageLoadWarning': 'Caricandola contatterai {host}.',
  'message.loadImage': 'Carica immagine',
  'message.load': 'Carica',
  'message.imageBlocked': 'bloccata',
  'message.image': 'Immagine',
  'message.resetZoom': 'Reimposta lo zoom',
  'message.linkBlockedNotice': 'Link bloccato',
  'message.sourceHeader': 'Origine',
  'keys.title': 'Chiavi',
  'keys.newKey': 'Nuova chiave',
  'keys.refreshFailed': "Impossibile aggiornare le chiavi. Mostro l’ultimo elenco noto.",
  'keys.sectionActive': 'Attive',
  'keys.sectionRevoked': 'Revocate',
  'keys.intro':
    'Le chiavi identificano chi ha inviato una notifica. Usa una chiave diversa per ogni script. ' +
    'La chiave predefinita è stata creata quando questo dispositivo è stato configurato.',
  'keys.aboutKeys': 'Informazioni sulle chiavi',
  'keys.sent': { one: '1 inviata', other: '{n} inviate' },
  'keys.rowLastUsed': 'usata {ago}',
  'keys.docsLink': 'API docs',
  'keys.chipDefault': 'Predefinita',
  'keys.chipRevoked': 'Revocata',
  'keys.chipCritical': 'Critica',
  'keys.rowLabel': 'Chiave, {name}, termina con {suffix}',
  'keys.rowLabelRevoked': ', revocata',
  'keys.rowLabelCritical': ', avvisi critici attivi',
  'keys.maskedValue': '{prefix}…',

  'keyDetail.notFound': 'Chiave non trovata',
  'keyDetail.notFoundDetail': 'Potrebbe essere stata rimossa su un altro dispositivo.',

  'keyDetail.criticalOn':
    'Gli invii da questa chiave che lo richiedono suoneranno anche in modalità silenziosa e con Focus attivo. ' +
    'Aggiungi is_critical=1 all\'invio.',
  'keyDetail.criticalTimeSensitive':
    'Gli invii da questa chiave che lo richiedono superano Focus e restano sulla schermata di blocco. ' +
    'Aggiungi is_critical=1 all\'invio. Non suoneranno in modalità silenziosa. ' +
    'Serve un\'autorizzazione che Apple non ha ancora concesso a notifi.',

  'keyDetail.copyKey': 'Copia chiave',
  'keyDetail.shareKey': 'Condividi chiave',
  'keyDetail.copyCurl': 'Copia curl',
  'keyDetail.examplesLink': 'Docs',
  'keyDetail.defaultKeyDetail':
    'notifi conserva questa chiave sul tuo dispositivo, così puoi copiarla di nuovo quando ' +
    'ti serve, oppure rigenerarla qui sotto.',
  'keyDetail.shownOnceDetail':
    'Il valore è stato mostrato una sola volta, alla creazione di questa chiave. Non è memorizzato sul dispositivo.',

  'keyDetail.sectionUsage': 'Utilizzo',
  'keyDetail.fieldSent': 'Inviate',
  'keyDetail.fieldCreated': 'Creata',
  'keyDetail.fieldLastUsed': 'Ultimo utilizzo',

  'keyDetail.openAnyLink': 'Apri qualsiasi link',
  'keyDetail.openAnyLinkDetail':
    'Disattivato, si aprono solo i link https. Attivato, si aprono anche altri schemi, inclusi quelli che ' +
    'avviano altre app su questo dispositivo.',

  'keyDetail.criticalAlerts': 'Avvisi critici',

  'keyDetail.revokedNotice': 'Questa chiave è revocata e non accetta più invii.',

  'keyDetail.sectionDanger': 'Zona pericolosa',
  'keyDetail.regenerate': 'Rigenera chiave',
  'keyDetail.regenerating': 'Rigenerazione…',
  'keyDetail.regenerateDetail':
    'La rigenerazione emette un nuovo valore e ritira quello vecchio. Qualsiasi invio ancora effettuato ' +
    'con il vecchio valore verrà rifiutato.',
  'keyDetail.revoke': 'Revoca chiave',
  'keyDetail.revoking': 'Revoca in corso…',
  'keyDetail.revokeDetail':
    'La revoca è permanente. Qualsiasi invio ancora effettuato verso questa chiave verrà rifiutato.',

  'keyDetail.revokeTitle': 'Revocare “{name}”?',
  'keyDetail.revokeTitleFallback': 'Revocare questa chiave?',
  'keyDetail.revokeConfirm': 'Revoca',
  'keyDetail.revokeMessage': 'Qualsiasi invio ancora effettuato verso di essa verrà rifiutato.',

  'keyDetail.regenerateTitle': 'Rigenerare “{name}”?',
  'keyDetail.regenerateTitleFallback': 'Rigenerare questa chiave?',
  'keyDetail.regenerateConfirm': 'Rigenera',
  'keyDetail.regenerateMessage':
    'Il valore attuale smette di funzionare immediatamente, e qualsiasi invio ancora effettuato con esso ' +
    'verrà rifiutato.',

  'keyDetail.regeneratedAnnouncement': 'Chiave rigenerata. Il vecchio valore non funziona più.',
  'keyDetail.regenerateFailed': 'Impossibile rigenerare la chiave. Controlla la connessione e riprova.',
  'keyDetail.revokedAnnouncement': 'Chiave revocata.',
  'keyDetail.revokeFailed': 'Impossibile revocare la chiave. Controlla la connessione e riprova.',

  'keyDetail.criticalNotPermitted':
    'Gli avvisi critici sono disattivati per notifi nelle impostazioni di sistema. Continueranno a ' +
    'superare Focus, ma non suoneranno in modalità silenziosa.',
  'keyDetail.criticalChangeFailed':
    'Impossibile modificare gli avvisi critici per questa chiave. Controlla la connessione e riprova.',

  'createKey.title': 'Nuova chiave',
  'createKey.intro': 'Un nome che vedi solo tu. Compare nell\'elenco delle chiavi e nei filtri.',
  'createKey.sectionName': 'Nome',
  'createKey.namePrompt': 'es. Avvisi Grafana',
  'createKey.nameLabel': 'Nome chiave',
  'createKey.charCount': '{n}/{max}',
  'createKey.nameReserved': '“default” è riservato. Il tuo dispositivo ne ha già uno.',
  'createKey.nameTaken': 'Una chiave con questo nome è già attiva.',
  'createKey.create': 'Crea chiave',
  'createKey.creating': 'Creazione…',

  'createKey.validationEmpty': 'Inserisci un nome per questa chiave.',
  'createKey.validationTooLong': 'Usa 64 caratteri o meno.',
  'createKey.validationReserved': 'Scegli un altro nome. “default” è la chiave del tuo dispositivo.',
  'createKey.validationTaken': 'Scegli un altro nome. Una delle tue chiavi attive lo usa già.',
  'createKey.createFailed': 'Impossibile creare la chiave. Controlla la connessione e riprova.',

  'createKey.revealTitle': 'Copia subito la tua chiave',
  'createKey.revealDetail': 'Non verrà mostrata di nuovo.',
  'createKey.revealLabel': 'La tua nuova chiave',
  'createKey.revealWarning':
    'Trattala come una password. Se la perdi, revoca la chiave e creane una nuova.',

  'createKey.leaveTitle': 'Non l\'hai ancora copiata?',
  'createKey.leaveCopyAndClose': 'Copia e chiudi',
  'createKey.leaveCloseAndRevoke': 'Chiudi e revoca',
  'createKey.leaveMessage': 'Questa chiave non verrà mai più mostrata.',

  'settings.title': 'Impostazioni',

  'settings.sectionPermissions': 'Autorizzazioni',
  'settings.permission': 'Autorizzazione',
  'settings.openSystemSettings': 'Apri impostazioni di sistema',

  'settings.permissionEnabled': 'Attiva',
  'settings.permissionOff': 'Disattivata',
  'settings.permissionProvisional': 'Provvisoria',
  'settings.permissionEphemeral': 'Effimera',
  'settings.permissionNotSet': 'Non impostata',
  'settings.permissionUnknown': 'Sconosciuta',

  'settings.theme': 'Tema',
  'settings.grain': 'Grana',
  'settings.grainDetail': 'Grana animata sulla campana e nelle schermate vuote.',
  'settings.themeDark': 'Scuro',
  'settings.themeLight': 'Chiaro',
  'settings.themeSystem': 'Sistema',

  'settings.loadImages': 'Carica le immagini automaticamente',
  'settings.loadImagesDetail':
    'Recupera ogni immagine all\'arrivo della notifica, il che comunica al suo host il tuo indirizzo IP. ' +
    'Disattivato, le immagini si caricano solo quando vengono toccate.',

  'settings.strictSend': 'Rifiuta invii non validi',
  'settings.strictSendDetail':
    'Restituisce 422 invalid_content e non memorizza nulla quando un titolo o un corpo supera la ' +
    'lunghezza consentita. Disattivato, /send abbrevia il campo e restituisce 202 con un array di warnings.',
  'settings.strictSendFailed': 'PATCH /devices/settings non riuscito. Controlla la connessione e riprova.',

  'settings.testTitle': 'Hello from notifi',
  'settings.testBody': 'La tua prima notifica.',

  'settings.macApp': 'Scarica per Mac',

  'settings.iosApp': 'Scarica su App Store',

  'settings.sectionSupport': 'Assistenza',
  'settings.sectionApplication': 'Applicazione',
  'settings.sectionAbout': 'Informazioni',
  'settings.version': 'Versione',
  'settings.openAtLogin': 'Apri all\'accesso',
  'settings.openAtLoginDetail': 'Avvia notifi nella barra dei menu quando accedi a questo Mac.',
  'settings.installUpdatesAutomatically': 'Installa gli aggiornamenti automaticamente',
  'settings.installUpdatesAutomaticallyDetail':
    'Scarica e installa le nuove versioni senza chiedere. notifi si riavvia quando si aggiorna.',
  'settings.checkForUpdates': 'Verifica aggiornamenti',
  'settings.deleteAll': 'Elimina tutte le notifiche',
  'settings.deleteAllTitle': 'Eliminare tutte le notifiche?',
  'settings.deleteAllConfirm': 'Elimina tutte',
  'settings.deleteAllMessage': 'Questa azione non può essere annullata.',
  'settings.support': 'Segnala un problema',
  'settings.feedback': 'Feedback',
  'settings.privacyPolicy': 'Informativa sulla privacy',
  'settings.website': 'notifi.it',

  'empty.sampleTitle': 'Hello from notifi',
  'empty.sampleMessage': 'La tua prima notifica.',

  'empty.title': 'Ancora niente',
  'empty.detail': 'Invia la tua prima notifica e apparirà qui.',

  'empty.stepAllow': 'Consenti le notifiche',
  'empty.notificationsOn': 'Le notifiche sono attive.',
  'empty.enableNotifications': 'Attiva le notifiche',

  'empty.stepSend': 'Inviane una',
  'empty.sendTest': 'Invia una prova',
  'empty.sending': 'Invio…',
  'empty.sent': 'Inviata. Arriverà qui e sulla schermata di blocco tra un momento.',
  'empty.sendFailed': 'Impossibile inviare. Controlla la connessione e riprova.',

  'empty.makingKey': 'Creazione della chiave…',
  'empty.makeKeyFailed': 'Impossibile creare una chiave. Controlla la connessione e riprova.',

  'empty.stepLabel': 'Passo {n}. {title}.',
  'empty.stepDone': ' Fatto.',

  'components.clearSearch': 'Cancella ricerca',
  'components.noMatches': 'Nessun risultato',
  'components.noMatchesDetail': 'Niente qui con questo filtro.',
  'components.noMatchesQuery': 'Nessun risultato per “{query}”.',
  'components.errorLabel': 'Errore. {message}',
  'components.backTo': 'Torna a {label}',
  'components.createKey': 'Crea chiave',

  'identity.title': 'Impossibile sbloccare notifi',
  'identity.detail':
    'notifi non è riuscito a leggere la sua chiave di identità dal portachiavi. Di solito si risolve una volta che il ' +
    'dispositivo è stato sbloccato. Le tue notifiche e le chiavi di invio non sono interessate.',

  'unsupported.title': 'Mac non supportato',
  'unsupported.detail':
    'notifi richiede un Mac con chip Apple Silicon o chip T2. Questo Mac non ha una Secure Enclave, ' +
    'che notifi usa per proteggere la tua chiave di identità.',

  'restore.title': 'Sembra un dispositivo nuovo',
  'restore.detail':
    'Le tue vecchie notifiche sono state ripristinate da un backup, ma le tue chiavi no. Le chiavi sono legate al ' +
    'dispositivo su cui sono state create e non possono essere spostate. Qualsiasi invio ancora effettuato verso le tue vecchie chiavi ' +
    'verrà ora rifiutato. Crea nuove chiavi per continuare a ricevere notifiche.',

  'clientErrors.unauthorized': 'Questa chiave non è più accettata. Creane una nuova in Chiavi.',
  'clientErrors.notFound': 'Non è più sul server. Aggiorna e riprova.',
  'clientErrors.rateLimited': 'Troppe richieste in questo momento. Riprova tra un momento.',
  'clientErrors.server': 'Il server sta avendo problemi. Riprova tra un momento.',
  'clientErrors.generic': 'La richiesta non è andata a buon fine. Riprova.',
  'clientErrors.transport': 'Impossibile raggiungere il server. Controlla la connessione e riprova.',
  'clientErrors.decoding': 'Il server ha restituito qualcosa di inatteso. Riprova tra un momento.',

  'store.name': 'notifi: notifiche push',
  'store.subtitle': 'Per script e server',
  'store.promotionalText':
    'Una richiesta HTTP e la notifica arriva sul tuo iPhone o Mac. Cifrato con la tua chiave ' +
    'pubblica: non possiamo leggere le tue notifiche. Niente account.',
  'store.keywords':
    'webhook,api,avvisare,allerta,auto,ospitato,cron,curl,cli,devops,homelab,ssh,docker,' +
    'monitor',
  'store.description':
    'Notifiche push per i tuoi script e server.\n\n' +
    'Crea una chiave di invio e manda un titolo e un corpo a notifi.it in un\'unica richiesta ' +
    'HTTP. La notifica arriva sul tuo iPhone o Mac. Qualsiasi cosa possa fare una richiesta HTTP ' +
    'può inviarne una, ad esempio uno script di shell, un cron job, una pipeline CI.\n\n' +
    'https://notifi.it/send?title=hello+world\n\n' +
    'COSA CONTIENE UNA NOTIFICA\n' +
    'Un titolo, un corpo, un\'immagine e un link. Il corpo è Markdown: titoli, elenchi, ' +
    'citazioni, link e blocchi di codice vengono visualizzati sul dispositivo.\n\n' +
    'CIFRATO\n' +
    'Il tuo dispositivo detiene l\'unica chiave privata. Il contenuto delle notifiche è cifrato con ' +
    'la tua chiave pubblica all\'ingresso, così non possiamo leggere le tue notifiche. Ogni ' +
    'notifica viene eliminata dal server una volta che il tuo dispositivo la conferma.\n\n' +
    'NIENTE ACCOUNT\n' +
    'Niente registrazione, niente accesso, nessun collegamento del dispositivo. L\'app genera una ' +
    'chiave di invio al primo avvio. Le chiavi possono essere rinominate, sospese e revocate per ' +
    'ogni fonte.\n\n' +
    'AVVISI URGENTI\n' +
    'Contrassegna una chiave come urgente e le sue notifiche superano Focus e arrivano sulla ' +
    'schermata di blocco.\n',
  'store.releaseNotes': 'Bug fixes and performance improvements.\n',
  'store.shotInboxTitle': 'Una richiesta.\nDritta in tasca.',
  'store.shotInboxTitleIpad': 'Una richiesta.\nDritta sui tuoi dispositivi.',
  'store.shotInboxBody':
    'Notifiche push per i tuoi script e server. Una richiesta HTTP a notifi.it e arriva un ' +
    'momento dopo. Niente account.',
  'store.shotMessageTitle': 'Immagini, link,\nMarkdown.',
  'store.shotMessageBody':
    'Un titolo, un corpo, un\'immagine e un link. Titoli, elenchi, citazioni e blocchi di codice ' +
    'sono renderizzati sul dispositivo. Cifrato con la tua chiave pubblica, quindi non possiamo ' +
    'leggere le tue notifiche.',
  'store.shotKeysTitle': 'Una chiave\nper fonte.',
  'store.shotKeysBody':
    'Dai al bot di deploy una chiave e al campanello un\'altra. Revocane una e le altre ' +
    'continuano a funzionare. Ogni chiave ha il proprio conteggio di invii, senza alcun account ' +
    'da creare prima.',
};
