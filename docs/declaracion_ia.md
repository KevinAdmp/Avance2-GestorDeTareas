# Declaración de uso de IA
**Autor:** Kevin Adrian Morales Palomo  
**Entrega:** Entrega Final — LSCA2314 · Periodo AD26  
**Fecha:** 28 de septiembre de 2026

---

## Herramienta utilizada

Usé **Kiro (Claude)** como asistente dentro del IDE durante el desarrollo de esta entrega.

---

## En qué me ayudó la IA

- Ejecutar los comandos del pipeline y guardar las salidas en los reportes
- Armar la estructura de los documentos de clasificación y respuesta al incidente
- Aplicar el fix de pickle → json en el código y correr Bandit para verificar
- Configurar la conexión a RDS y actualizar el docker-compose
- Resolver errores técnicos del despliegue en EC2 (psycopg2, Security Groups, docker-compose)

## Qué decidí yo

- Confirmar que el hallazgo B301 no es falso positivo — revisé manualmente que el dato viene de la cola y no hay validación previa
- Subir la severidad de Medium a Alta — Bandit no sabe que el dato es externo, yo sí
- Elegir JSON sobre otras opciones como msgpack o protobuf — JSON ya es el formato que usa la cola en el resto del proyecto, no tiene sentido introducir otra dependencia
- Entender el flujo completo de QA a Producción y qué significa cada paso
- Leer e interpretar los comentarios del profe del Avance 2 para no repetir los mismos errores

## Lo que aprendí

Lo que más me costó fue entender por qué pickle es peligroso con datos externos específicamente. A primera vista el código parece normal — recibe un mensaje, lo decodifica, lo usa. El problema no es el código en sí sino de dónde viene el dato. Esa distinción entre dato interno y externo es lo que define si la vulnerabilidad es real o teórica, y eso no lo puede decidir una herramienta automática.
