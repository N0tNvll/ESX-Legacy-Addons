# Chat y comandos de rol unificados

`esx_chat` reúne la interfaz de chat, los comandos de rol y los mensajes privados.
Incluye `/me`, `/do`, `/environment`, `/dice`, `/try`, `/ooc`, `/twt`, `/anontwt`,
`/job`, `/pm`, `/msg`, `/report` y `/help`. `/msg` es un alias de `/pm` y comparte
su límite de envío. Los comandos, permisos y canales se configuran en `config.lua`.

## Instalación y actualización

1. Guarda tus configuraciones personalizadas.
2. Detén y retira `esx_rpchat` y quita su entrada `ensure` del servidor.
3. Detén el chat predeterminado de FiveM y sustituye `ensure chat` por
   `ensure esx_chat`. Despliega el recurso completo, incluidos los idiomas.
4. Inicia `esx_chat` después de `es_extended` y `esx_lib`.

```cfg
ensure esx_chat
```

Este recurso proporciona `chat` y `esx_rpchat` mediante la
[sustitución de recursos de FiveM](https://docs.fivem.net/docs/scripting-reference/resource-manifest/#provide).
Solo se necesita esta interfaz; `esx_chat_theme` corresponde al antiguo chat.
No hay cambios SQL ni una compilación nueva de la interfaz para esta integración.

## Opciones trasladadas

- `EnableESXIdentity` y `OnlyFirstname` controlan el nombre mostrado.
- `ProximityDistance` limita los mensajes de rol a los jugadores cercanos en
  la misma instancia; el emisor también recibe su mensaje.
- `ProximityMaxLength` limita las acciones de proximidad por caracteres Unicode.
- `CommandCooldowns` conserva los tiempos por comando del chat de rol. El
  límite global `RateLimit` continúa protegiendo el conjunto de mensajes.
- Las preferencias de visibilidad conservan la clave `esx_chat:displayMode`.

El servidor valida destinatarios y permisos. Los mensajes privados se entregan
solo al emisor y al destinatario. Los tweets anónimos ocultan el autor al público,
pero mantienen su identidad en los registros de moderación existentes.

## Compatibilidad

El área de mensajes reserva una altura predeterminada de `calc(var(--u) * 470)`
en `web/style.css`, aunque haya pocos mensajes o esté vacía. La escala y el ancho
conservan su adaptación a la resolución. La altura solo se reduce cuando falta
espacio en pantalla; las sugerencias permiten desplazarse. Las cajas no usan sombras
ni desenfoque de fondo.

Se mantienen `chat:addMessage`, `chatMessage`, las sugerencias, las plantillas y
`chat:clear`, además de las dos firmas de `esx_rpchat:sendProximityMessage`.
Los exports básicos `chat:addMessage` de cliente y servidor y `chat:addSuggestion`
de cliente llegan a la misma interfaz que sus equivalentes en `esx_chat`.
`_chat:messageEntered` pasa por la validación del servidor y la cancelación de
`chatMessage`; los nombres suministrados por el cliente no sustituyen su identidad.

Las personalizaciones de configuraciones antiguas se trasladan a `config.lua`;
el recurso no lee archivos de las carpetas retiradas.
