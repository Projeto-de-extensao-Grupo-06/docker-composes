set -e

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-solarway}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"

S3_BUCKET="${S3_BUCKET:?Variável S3_BUCKET não definida}"
S3_PREFIX="${S3_PREFIX:-backups}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DUMP_FILE="/tmp/dump_${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Aguardando MySQL em ${MYSQL_HOST}:${MYSQL_PORT}..."
until mysqladmin ping -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
  sleep 3
done
log "MySQL disponível."

log "Iniciando dump de '${MYSQL_DATABASE}'..."
mysqldump \
  -h"${MYSQL_HOST}" \
  -P"${MYSQL_PORT}" \
  -u"${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  --databases "${MYSQL_DATABASE}" \
  | gzip > "${DUMP_FILE}"

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
log "Dump concluído: ${DUMP_FILE} (${DUMP_SIZE})"

S3_KEY="${S3_PREFIX}/${MYSQL_DATABASE}/${TIMESTAMP}/dump.sql.gz"
S3_URI="s3://${S3_BUCKET}/${S3_KEY}"

log "Enviando para ${S3_URI}..."
aws s3 cp "${DUMP_FILE}" "${S3_URI}" \
  --storage-class STANDARD_IA

log "Upload concluído: ${S3_URI}"

rm -f "${DUMP_FILE}"
log "Arquivo temporário removido."

RETENTION_DAYS="${RETENTION_DAYS:-30}"
CUTOFF=$(date -d "-${RETENTION_DAYS} days" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
         || date -v-"${RETENTION_DAYS}"d +"%Y-%m-%dT%H:%M:%S")

log "Removendo dumps com mais de ${RETENTION_DAYS} dias em s3://${S3_BUCKET}/${S3_PREFIX}/${MYSQL_DATABASE}/..."
aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${MYSQL_DATABASE}/" \
  | awk '{print $2}' \
  | while read -r PREFIX; do
      FOLDER_DATE=$(echo "${PREFIX}" | grep -oE '[0-9]{8}' | head -1)
      if [ -n "${FOLDER_DATE}" ]; then
        FOLDER_ISO="${FOLDER_DATE:0:4}-${FOLDER_DATE:4:2}-${FOLDER_DATE:6:2}T00:00:00"
        if [ "${FOLDER_ISO}" \< "${CUTOFF}" ]; then
          log "  Removendo prefixo antigo: ${PREFIX}"
          aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${MYSQL_DATABASE}/${PREFIX}" --recursive
        fi
      fi
    done

log "Enviando email via SMTP..."

export MYSQL_DATABASE
export S3_URI
export TIMESTAMP
export SMTP_HOST
export SMTP_PORT
export SMTP_USER
export SMTP_PASS
export SMTP_FROM
export EMAIL_TO

python3 - <<EOF
import smtplib
from email.mime.text import MIMEText
import os

smtp_host = os.environ['SMTP_HOST']
smtp_port = int(os.environ['SMTP_PORT'])
smtp_user = os.environ['SMTP_USER']
smtp_pass = os.environ['SMTP_PASS']

from_email = os.environ['SMTP_FROM']
to_email = os.environ['EMAIL_TO']

body = f"""
Backup finalizado com sucesso!

Banco: {os.environ['MYSQL_DATABASE']}
Arquivo: {os.environ['S3_URI']}
Timestamp: {os.environ['TIMESTAMP']}
"""

msg = MIMEText(body)
msg['Subject'] = f"Backup MySQL - {os.environ['MYSQL_DATABASE']}"
msg['From'] = from_email
msg['To'] = to_email

server = smtplib.SMTP(smtp_host, smtp_port)
server.starttls()
server.login(smtp_user, smtp_pass)
server.sendmail(from_email, [to_email], msg.as_string())
server.quit()

print("Email enviado com sucesso")
EOF

log "=== Backup finalizado com sucesso ==="