# escape=`

ARG BASE_IMAGE
ARG SXA_IMAGE
ARG SPE_IMAGE
ARG HORIZON_RESOURCES_IMAGE

FROM ${SPE_IMAGE} as spe
FROM ${SXA_IMAGE} as sxa
FROM ${HORIZON_RESOURCES_IMAGE} as horizon_resourses
FROM ${BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

COPY --from=spe C:\module\db C:\resources\spe
COPY --from=sxa C:\module\db C:\resources\sxa
COPY --from=horizon_resourses C:\module\db C:\resources\hrz
