import type { Translation } from '../types.js';

export const es: Translation = {
  'api.notFound': 'No encontrado.',
  'api.unexpected': 'Error inesperado.',

  'api.rateLimitedIP': 'Demasiadas solicitudes desde esta IP.',
  'api.rateLimitedAccount': 'Límite de solicitudes superado. Demasiadas notificaciones esta hora.',

  'api.badSignature': 'Firma de solicitud no válida.',
  'api.staleTimestamp': 'La marca de tiempo de la solicitud está fuera del margen permitido.',

  'api.unknownDevice': 'El dispositivo no está registrado.',
  'api.unknownKey': 'Clave desconocida o revocada.',
  'api.keyNotFound': 'Clave no encontrada.',
  'api.activeKeyLimit': 'Se alcanzó el límite de claves activas.',

  'api.invalidDeviceBody': 'Cuerpo de registro de dispositivo no válido.',
  'api.publicKeyMismatch': 'public_key debe coincidir con la clave pública de firma.',
  'api.invalidEncryptionKey': 'encryption_public_key no es un punto P-256 válido.',
  'api.invalidCreateKeyBody': 'Cuerpo de creación de clave no válido.',
  'api.invalidUpdateKeyBody': 'Cuerpo de actualización de clave no válido.',
  'api.invalidDeviceSettingsBody': 'Cuerpo de ajustes de dispositivo no válido.',
  'api.invalidHistoryQuery': 'Consulta de historial no válida.',
  'api.invalidSendParams': 'Parámetros de envío no válidos.',
  'api.occurredAtTooFuture': 'occurred_at está demasiado lejos en el futuro.',
  'api.criticalNotAllowed':
    'Enviado como notificación normal: las alertas críticas están desactivadas para esta clave.',
  'api.titleCropped': 'Enviado con un título acortado: superaba los {max} caracteres.',
  'api.messageCropped': 'Enviado con un mensaje acortado: superaba los {max} caracteres.',
  'api.imageRejected': 'Enviado sin la imagen: esa no es una dirección que vayamos a obtener.',
  'api.imageUnreachable':
    'Enviado sin la imagen: no respondió con un PNG, JPEG o GIF de menos de 5 MB.',
  'api.strictContentRejected':
    'No enviado. Este dispositivo está configurado para rechazar un mensaje que no puede entregar tal como está escrito.',

  'api.noMacBuild': 'Todavía no se ha publicado ninguna compilación de macOS.',
  'api.noSuchBuild': 'No existe esa compilación.',

  'push.fallbackTitle': 'notifi',
  'push.fallbackBody': 'Abre notifi para verlo',
  'push.actionOpenLink': 'Abrir enlace',
  'push.actionMarkAsRead': 'Marcar como leído',
  'push.summaryFormat': '%%u más de {name}',

  'common.cancel': 'Cancelar',
  'common.close': 'Cerrar',
  'common.delete': 'Eliminar',
  'common.done': 'Hecho',
  'common.copy': 'Copiar',
  'common.copied': 'Copiado',
  'common.share': 'Compartir',
  'common.clear': 'Borrar',
  'common.search': 'Buscar',
  'common.tryAgain': 'Inténtalo de nuevo',
  'common.continueAction': 'Continuar',
  'common.quit': 'Salir',
  'common.markAsRead': 'Marcar como leído',
  'common.markAsUnread': 'Marcar como no leído',
  'common.openLink': 'Abrir enlace',
  'common.never': 'Nunca',
  'common.expand': 'Expandir',
  'common.collapse': 'Contraer',

  'tabs.notifications': 'Notificaciones',
  'tabs.keys': 'Claves',
  'tabs.settings': 'Ajustes',
  'tabs.inbox': 'Bandeja',

  'age.now': 'ahora',
  'age.justNow': 'ahora mismo',
  'age.minutes': '{n} min',
  'age.hours': '{n} h',
  'age.days': '{n} d',
  'age.weeks': '{n} sem',
  'age.ago': 'hace {relative}',
  'age.absoluteFormat': 'EEE d MMM yyyy, HH:mm:ss.SSS',

  'inbox.title': 'Notificaciones',
  'inbox.offline': 'No se puede conectar con los servidores de notifi. Comprueba tu conexión e inténtalo de nuevo.',
  'inbox.count': { one: '1 notificación', other: '{n} notificaciones' },
  'inbox.unreadSummary': ' sin leer · {total}',
  'inbox.filteredToKey': 'Filtrado por la clave "{name}".',
  'inbox.closeSearch': 'Cerrar búsqueda',
  'inbox.markAllAsRead': 'Marcar todo como leído',
  'inbox.filterByKey': 'Filtrar por clave',
  'inbox.allKeys': 'Todas las claves',
  'inbox.refresh': 'Actualizar',
  'inbox.more': 'Más',
  'inbox.copyTitle': 'Copiar título',
  'inbox.copyMessage': 'Copiar mensaje',
  'inbox.copyLink': 'Copiar enlace',
  'inbox.seedSampleData': 'Generar datos de ejemplo',
  'inbox.clearSampleData': 'Borrar datos de ejemplo',

  'inbox.bandToday': 'Hoy',
  'inbox.bandYesterday': 'Ayer',
  'inbox.bandEarlierThisWeek': 'Antes esta semana',
  'inbox.bandEarlierThisMonth': 'Antes este mes',
  'inbox.bandLabel': '{title}, {count}',

  'inbox.unread': 'Sin leer',
  'inbox.critical': 'Crítica',
  'inbox.linkTo': 'Enlace a {host}',
  'inbox.rowKey': 'Clave {label}',

  'inbox.deleteTitle': '¿Eliminar "{title}"?',
  'inbox.deleteTitleFallback': '¿Eliminar esta notificación?',
  'inbox.deleteMessage': 'Esto no se puede deshacer.',

  'search.prompt': 'Buscar notificaciones',
  'search.matches': { one: '1 coincidencia', other: '{n} coincidencias' },

  'message.notFound': 'Mensaje no encontrado',
  'message.notFoundDetail': 'Puede que se haya eliminado en este dispositivo.',
  'message.downloadImage': 'Descargar imagen',
  'message.backToNotifications': 'Volver a Notificaciones',
  'message.keyFallbackName': 'Clave {id}',
  'message.sentWithKey': 'Enviado con la clave {name}',
  'message.openKey': 'Enviado con la clave {name}. Ábrela.',
  'message.viewImageFullScreen': 'Ver imagen a pantalla completa',
  'message.linksTo': 'Enlaza a {host}',
  'message.shareLink': 'Compartir enlace',
  'message.imageFailedToLoad': 'No se pudo cargar la imagen',
  'message.imageHidden': 'Imagen oculta',
  'message.imageHost': 'otro host',
  'message.imageLoadWarning': 'Cargarla contacta con {host}.',
  'message.loadImage': 'Cargar imagen',
  'message.load': 'Cargar',
  'message.imageBlocked': 'bloqueada',
  'message.sourceHeader': 'Origen',
  'message.copyTimestamp': 'Copiar marca de tiempo',

  'keys.title': 'Claves',
  'keys.newKey': 'Nueva clave',
  'keys.active': { one: '1 activa', other: '{n} activas' },
  'keys.criticalSummary': '{active} · {n} críticas',
  'keys.refreshFailed': 'No se pudieron actualizar las claves. Mostrando la última lista conocida.',
  'keys.sectionActive': 'Activas',
  'keys.sectionRevoked': 'Revocadas',
  'keys.intro':
    'Las claves identifican quién envió un mensaje. Usa una clave distinta para cada script. ' +
    'La clave predeterminada se creó al configurar este dispositivo.',
  'keys.aboutKeys': 'Acerca de las claves',
  'keys.footnote':
    'Una clave se muestra una sola vez, al crearla; notifi solo guarda el prefijo. ' +
    'La clave predeterminada se puede volver a copiar o regenerar desde su página de detalle.',
  'keys.sent': { one: '1 enviada', other: '{n} enviadas' },
  'keys.rowLastUsed': 'usada {ago}',
  'keys.docsLink': 'API docs',
  'keys.chipDefault': 'Predeterminada',
  'keys.chipRevoked': 'Revocada',
  'keys.chipCritical': 'Crítica',
  'keys.rowLabel': 'Clave, {name}, termina en {suffix}',
  'keys.rowLabelRevoked': ', revocada',
  'keys.rowLabelCritical': ', alertas críticas activadas',
  'keys.maskedValue': '{prefix}…',

  'keyDetail.notFound': 'Clave no encontrada',
  'keyDetail.notFoundDetail': 'Puede que se haya eliminado en otro dispositivo.',

  'keyDetail.criticalOn':
    'Los envíos de esta clave que lo soliciten sonarán incluso con el modo silencio y el modo Enfoque activados. ' +
    'Añade is_critical=1 al envío.',
  'keyDetail.criticalTimeSensitive':
    'Los envíos de esta clave que lo soliciten atravesarán el modo Enfoque y permanecerán en la pantalla de ' +
    'bloqueo. Añade is_critical=1 al envío. No sonarán con el modo silencio activado. ' +
    'Eso requiere una autorización que Apple aún no ha concedido a notifi.',

  'keyDetail.copyKey': 'Copiar clave',
  'keyDetail.shareKey': 'Compartir clave',
  'keyDetail.copyCurl': 'Copiar curl',
  'keyDetail.examplesLink': 'Más formas de enviar',
  'keyDetail.defaultKeyDetail':
    'notifi guarda esta en tu dispositivo, así que puedes volver a copiarla cuando la necesites, ' +
    'o regenerarla más abajo.',
  'keyDetail.shownOnceDetail':
    'El valor se mostró una sola vez, al crear esta clave. No se guarda en el dispositivo.',

  'keyDetail.sectionUsage': 'Uso',
  'keyDetail.fieldSent': 'Enviadas',
  'keyDetail.fieldCreated': 'Creada',
  'keyDetail.fieldLastUsed': 'Último uso',

  'keyDetail.sectionLinks': 'Enlaces',
  'keyDetail.openAnyLink': 'Abrir cualquier enlace',
  'keyDetail.openAnyLinkDetail':
    'Desactivado, solo se abren enlaces https. Activado, también se abren otros esquemas, incluidos los que ' +
    'lanzan otras apps en este dispositivo.',

  'keyDetail.sectionAlerts': 'Alertas',
  'keyDetail.criticalAlerts': 'Alertas críticas',

  'keyDetail.revokedNotice': 'Esta clave está revocada y ya no acepta envíos.',

  'keyDetail.sectionDanger': 'Zona de riesgo',
  'keyDetail.regenerate': 'Regenerar clave',
  'keyDetail.regenerating': 'Regenerando…',
  'keyDetail.regenerateDetail':
    'Regenerar emite un nuevo valor y retira el anterior. Cualquier envío que siga usando ' +
    'el valor anterior será rechazado.',
  'keyDetail.revoke': 'Revocar clave',
  'keyDetail.revoking': 'Revocando…',
  'keyDetail.revokeDetail':
    'Revocar es permanente. Cualquier envío que siga dirigido a esta clave será rechazado.',

  'keyDetail.revokeTitle': '¿Revocar "{name}"?',
  'keyDetail.revokeTitleFallback': '¿Revocar esta clave?',
  'keyDetail.revokeConfirm': 'Revocar',
  'keyDetail.revokeMessage': 'Cualquier envío que siga dirigido a ella será rechazado.',

  'keyDetail.regenerateTitle': '¿Regenerar "{name}"?',
  'keyDetail.regenerateTitleFallback': '¿Regenerar esta clave?',
  'keyDetail.regenerateConfirm': 'Regenerar',
  'keyDetail.regenerateMessage':
    'El valor actual deja de funcionar de inmediato, y cualquier envío que siga usándolo ' +
    'será rechazado.',

  'keyDetail.regeneratedAnnouncement': 'Clave regenerada. El valor anterior ya no funciona.',
  'keyDetail.regenerateFailed': 'No se pudo regenerar la clave. Comprueba tu conexión e inténtalo de nuevo.',
  'keyDetail.revokedAnnouncement': 'Clave revocada.',
  'keyDetail.revokeFailed': 'No se pudo revocar la clave. Comprueba tu conexión e inténtalo de nuevo.',

  'keyDetail.criticalNotPermitted':
    'Las alertas críticas están desactivadas para notifi en los ajustes del sistema. Seguirán ' +
    'atravesando el modo Enfoque, pero no sonarán con el modo silencio activado.',
  'keyDetail.criticalChangeFailed':
    'No se pudieron cambiar las alertas críticas de esta clave. Comprueba tu conexión e inténtalo de nuevo.',

  'createKey.title': 'Nueva clave',
  'createKey.intro': 'Un nombre que solo tú ves. Aparece en la lista de claves y en los filtros.',
  'createKey.sectionName': 'Nombre',
  'createKey.namePrompt': 'p. ej. Alertas de Grafana',
  'createKey.nameLabel': 'Nombre de la clave',
  'createKey.charCount': '{n}/{max}',
  'createKey.nameReserved': '"default" está reservado. Tu dispositivo ya tiene uno.',
  'createKey.nameTaken': 'Ya hay una clave activa con este nombre.',
  'createKey.create': 'Crear clave',
  'createKey.creating': 'Creando…',

  'createKey.validationEmpty': 'Escribe un nombre para esta clave.',
  'createKey.validationTooLong': 'Usa 64 caracteres o menos.',
  'createKey.validationReserved': 'Elige otro nombre. "default" es la clave propia de tu dispositivo.',
  'createKey.validationTaken': 'Elige otro nombre. Una de tus claves activas ya tiene este.',
  'createKey.createFailed': 'No se pudo crear la clave. Comprueba tu conexión e inténtalo de nuevo.',

  'createKey.revealTitle': 'Copia tu clave ahora',
  'createKey.revealDetail': 'No se volverá a mostrar.',
  'createKey.revealLabel': 'Tu nueva clave',
  'createKey.revealWarning':
    'Trátala como una contraseña. Si la pierdes, revoca la clave y crea una nueva.',

  'createKey.leaveTitle': '¿No la has copiado?',
  'createKey.leaveCopyAndClose': 'Copiar y cerrar',
  'createKey.leaveCloseAndRevoke': 'Cerrar y revocar',
  'createKey.leaveMessage': 'Esta clave no se volverá a mostrar nunca.',

  'settings.title': 'Ajustes',

  'settings.sectionPermissions': 'Permisos',
  'settings.permission': 'Permiso',
  'settings.openSystemSettings': 'Abrir ajustes del sistema',

  'settings.permissionEnabled': 'Activado',
  'settings.permissionOff': 'Desactivado',
  'settings.permissionProvisional': 'Provisional',
  'settings.permissionEphemeral': 'Efímero',
  'settings.delivery': 'Entrega',
  'settings.deliveryBroken': 'Sin envío',
  'settings.deliveryBrokenDetail':
    'Han llegado mensajes recientes sin una notificación detrás. Las notificaciones '
    + 'no están llegando a este dispositivo; los mensajes siguen llegando por su conexión '
    + 'en vivo, y siempre que la app se abre o se actualiza.',
  'settings.permissionNotSet': 'Sin definir',
  'settings.permissionUnknown': 'Desconocido',

  'settings.sectionAppearance': 'Apariencia',
  'settings.theme': 'Tema',
  'settings.themeDark': 'Oscuro',
  'settings.themeLight': 'Claro',

  'settings.loadImages': 'Cargar imágenes automáticamente',
  'settings.loadImagesDetail':
    'Obtiene cada imagen al llegar el mensaje, lo que informa tu dirección IP a su host. ' +
    'Desactivado, las imágenes solo se cargan al pulsarlas.',

  'settings.strictSend': 'Rechazar envíos no válidos',
  'settings.strictSendDetail':
    'Devuelve 422 invalid_content y no guarda nada cuando un título o mensaje supera la ' +
    'longitud o una URL de imagen no pasa la validación. Desactivado, /send recorta o descarta el campo y ' +
    'devuelve 202 con un array de avisos.',
  'settings.strictSendFailed': 'PATCH /devices/settings falló. Comprueba tu conexión e inténtalo de nuevo.',

  'settings.testTitle': 'Notificación de prueba',
  'settings.testBody': 'Si puedes leer esto, notifi está funcionando.',

  'settings.sectionSupport': 'Ayuda',
  'settings.sectionApplication': 'Aplicación',
  'settings.sectionAbout': 'Acerca de',
  'settings.version': 'Versión',
  'settings.openAtLogin': 'Abrir al iniciar sesión',
  'settings.openAtLoginDetail': 'Inicia notifi en la barra de menús al iniciar sesión en este Mac.',
  'settings.automaticUpdates': 'Actualizaciones automáticas',
  'settings.automaticUpdatesDetail': 'Busca nuevas versiones en segundo plano.',
  'settings.checkForUpdates': 'Buscar actualizaciones',
  'settings.support': 'Informar de un problema',
  'settings.feedback': 'Comentarios',
  'settings.privacyPolicy': 'Política de privacidad',
  'settings.website': 'notifi.it',

  'empty.sampleTitle': 'Hola Mundo',
  'empty.sampleMessage': 'Esto vino del comando que acabas de ejecutar.',

  'empty.title': 'Nada por aquí',
  'empty.detail': 'Envía tu primera notificación y aparecerá aquí.',

  'empty.stepAllow': 'Permitir notificaciones',
  'empty.notificationsOn': 'Las notificaciones están activadas.',
  'empty.enableNotifications': 'Activar notificaciones',

  'empty.stepSend': 'Envía una',
  'empty.sendTest': 'Enviar una prueba',
  'empty.sending': 'Enviando…',
  'empty.sent': 'Enviado. Llegará aquí y a tu pantalla de bloqueo en un momento.',
  'empty.sentDetail':
    'Llega aquí y a tu pantalla de bloqueo. Crea más claves en Claves para mantener las fuentes separadas.',
  'empty.sendFailed': 'No se pudo enviar. Comprueba tu conexión e inténtalo de nuevo.',

  'empty.makingKey': 'Creando tu clave…',
  'empty.makeKeyFailed': 'No se pudo crear una clave. Comprueba tu conexión e inténtalo de nuevo.',

  'empty.stepLabel': 'Paso {n}. {title}.',
  'empty.stepDone': ' Hecho.',

  'components.clearSearch': 'Borrar búsqueda',
  'components.noMatches': 'Sin coincidencias',
  'components.noMatchesDetail': 'Nada aquí con ese filtro.',
  'components.noMatchesQuery': 'Nada coincide con "{query}".',
  'components.errorLabel': 'Error. {message}',
  'components.backTo': 'Volver a {label}',
  'components.createKey': 'Crear clave',
  'components.wordmark': 'notifi',

  'identity.title': 'No se puede desbloquear notifi',
  'identity.detail':
    'notifi no pudo leer su clave de identidad del llavero. Esto suele resolverse una vez que el ' +
    'dispositivo se ha desbloqueado. Tus mensajes y claves de envío no se ven afectados.',

  'unsupported.title': 'Mac no compatible',
  'unsupported.detail':
    'notifi requiere un Mac con Apple silicon o un chip T2. Este Mac no tiene Secure Enclave, ' +
    'que notifi usa para proteger tu clave de identidad.',

  'restore.title': 'Esto parece un dispositivo nuevo',
  'restore.detail':
    'Tus mensajes antiguos se restauraron desde una copia de seguridad, pero tus claves no. Las claves están ligadas al ' +
    'dispositivo en el que se crearon y no se pueden trasladar. Cualquier envío que siga dirigido a tus claves antiguas ' +
    'será rechazado. Crea claves nuevas para seguir recibiendo notificaciones.',

  'clientErrors.unauthorized': 'Esta clave ya no se acepta. Crea una nueva en Claves.',
  'clientErrors.notFound': 'Eso ya no está en el servidor. Actualiza e inténtalo de nuevo.',
  'clientErrors.rateLimited': 'Demasiadas solicitudes en este momento. Inténtalo de nuevo en un momento.',
  'clientErrors.server': 'El servidor está teniendo problemas. Inténtalo de nuevo en un momento.',
  'clientErrors.generic': 'La solicitud no se pudo completar. Inténtalo de nuevo.',
  'clientErrors.transport': 'No se pudo conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo.',
  'clientErrors.decoding': 'El servidor devolvió algo inesperado. Inténtalo de nuevo en un momento.',

  'store.subtitle': 'Una solicitud HTTP, un aviso',
  'store.promotionalText':
    'Una solicitud HTTP y la notificación llega a tu iPhone o Mac. Cifrado con tu clave pública: ' +
    'no podemos leer tus mensajes. Sin cuentas, sin SDK.',
  'store.keywords':
    'curl,webhook,api,alerta,cli,servidor,monitor,cron,script,desarrollador,terminal,devops,' +
    'homelab,pager',
  'store.description':
    'Notificaciones push para tus scripts y servidores.\n\n' +
    'Crea una clave de envío y manda un título y un mensaje a notifi.it en una solicitud HTTP. ' +
    'La notificación llega a tu iPhone o Mac. Cualquier cosa que pueda hacer una solicitud HTTP ' +
    'puede enviar una, por ejemplo un script de shell, una tarea cron o un pipeline de CI.\n\n' +
    'https://notifi.it/send?title=hello+world\n\n' +
    'CIFRADO\n' +
    'Tu dispositivo guarda la única clave privada. El contenido del mensaje se cifra con tu clave ' +
    'pública al ingresar, así que no podemos leer tus mensajes. Cada mensaje se elimina del ' +
    'servidor en cuanto tu dispositivo lo confirma.\n\n' +
    'SIN CUENTAS\n' +
    'Sin registro, sin inicio de sesión, sin vincular dispositivos. La app crea una clave de envío ' +
    'en el primer inicio. Las claves se pueden renombrar, pausar y revocar por fuente.\n\n' +
    'ALERTAS URGENTES\n' +
    'Marca una clave como urgente y sus notificaciones atraviesan el modo Enfoque y aparecen en la ' +
    'pantalla de bloqueo.\n',
  'store.releaseNotes':
    'notifi 2.0 es una reescritura desde cero. La antigua app en Flutter ha desaparecido; esta es ' +
    'Swift nativo, rediseñada de arriba abajo.\n\n' +
    'Inicio más rápido, renderizado de texto nativo y un mismo diseño compartido entre las tres ' +
    'pestañas. La pantalla de Claves ahora explica qué es una clave, y la clave predeterminada ' +
    'encabeza la lista. Las marcas de tiempo de los mensajes son dígitos simples que puedes copiar.\n',

  'store.shotInboxTitle': 'Una solicitud.\nDirecto a tu bolsillo.',
  'store.shotInboxBody':
    'Notificaciones push para tus scripts y servidores. Una solicitud HTTP a notifi.it y llega un ' +
    'momento después. Sin cuenta, sin SDK.',
  'store.shotMessageTitle': 'Imágenes, enlaces,\nMarkdown.',
  'store.shotMessageBody':
    'Un título, un cuerpo, una imagen y un enlace. Encabezados, listas, citas y bloques de código ' +
    'se muestran en el dispositivo. Cifrado con tu clave pública, así que no podemos leer tus mensajes.',
  'store.shotKeysTitle': 'Una clave\npor fuente.',
  'store.shotKeysBody':
    'Dale al bot de despliegue una clave y al timbre otra. Revoca una y las demás siguen ' +
    'funcionando. Cada clave lleva su propio contador de envíos, y no hace falta crear una cuenta.',
};
