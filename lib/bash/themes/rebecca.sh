# shellcheck shell=bash
# shellcheck disable=SC2034

THEME_COLOR_BASE="$(escseq::sgr --fg-rgb '239:247:254')"
THEME_COLOR_MAIN="$(escseq::sgr --fg-rgb '95:95:255')"
THEME_COLOR_SUB="$(escseq::sgr --fg-rgb '148:140:243')"
THEME_COLOR_ACCENT="$(escseq::sgr --fg-rgb '236:148:173')"
THEME_COLOR_MUTED="$(escseq::sgr --fg-rgb '104:116:179')"

THEME_COLOR_FATAL="$(escseq::sgr --fg-rgb '255:0:0')"
THEME_COLOR_ERROR="$(escseq::sgr --fg-rgb '234:89:80')"
THEME_COLOR_WARN="$(escseq::sgr --fg-rgb '250:239:81')"
THEME_COLOR_NOTICE="$(escseq::sgr --fg-rgb '201:249:220')"
THEME_COLOR_INFO="$(escseq::sgr --fg-rgb '125:187:250')"
THEME_COLOR_DEBUG="$(escseq::sgr --fg-rgb '104:116:179')"

THEME_COLOR_SUCCESS="$(escseq::sgr --fg-rgb '4:219:181')"
THEME_COLOR_FAILURE="$(escseq::sgr --fg-rgb '234:89:80')"

THEME_COLOR_HEALTHY="$(escseq::sgr --fg-rgb '99:214:181')"
THEME_COLOR_UNHEALTHY="$(escseq::sgr --fg-rgb '234:89:80')"

THEME_COLOR_COMPLETE="$(escseq::sgr --fg-rgb '236:148:173')"
THEME_COLOR_DANGER="$(escseq::sgr --fg-rgb '234:89:80')"

#THEME_COLOR_LIMEGREEN="$(escseq::sgr --fg-rgb '192:239:94')"
#THEME_COLOR_GREEN="$(escseq::sgr --fg-rgb '117:251:88')"
#THEME_COLOR_GRAY="$(escseq::sgr --fg-rgb '156:158:163')"
