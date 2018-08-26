FROM sharelatex/sharelatex

# sharelatex ships with a repository configuration incompatible with today's
#   repositories. Set it up to use the old repository, then download everything
RUN tlmgr option repository ftp://tug.org/historic/systems/texlive/2017/tlnet-final

# Gradually install increasing schemes to have a few more fallback layers to
#   recover from if any installation fails. Comment in/out certain sets of
#   packages to get different degrees of installations.
# Note: The full scheme can take several hours to install, since it runs all
#   package installations serially, rather than concurrently.
RUN tlmgr install scheme-basic
RUN tlmgr install scheme-small
RUN tlmgr install scheme-medium
# RUN tlmgr install scheme-full

ENV SHARELATEX_REDIS_HOST redis.local
ENV SHARELATEX_MONGO_URL mongodb://mongodb.local:27017/share-latex
