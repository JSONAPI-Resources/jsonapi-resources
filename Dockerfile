FROM buildpack-deps:bullseye

# Install rbenv
RUN git clone https://github.com/sstephenson/rbenv.git /root/.rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git /root/.rbenv/plugins/ruby-build
RUN /root/.rbenv/plugins/ruby-build/install.sh
ENV PATH /root/.rbenv/bin:/root/.rbenv/shims:$PATH
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh # or /etc/profile
RUN echo 'eval "$(rbenv init -)"' >> .bashrc

# Install supported ruby versions
RUN echo 'gem: --no-document' >> ~/.gemrc

COPY .docker/ruby_versions.txt /
RUN xargs -I % sh -c 'rbenv install %; rbenv global %; gem install bundler' < ruby_versions.txt
RUN rbenv rehash

# COPY just enough to bundle. This allows for most code changes without needing to reinstall all gems
RUN mkdir src
COPY Gemfile jsonapi-resources.gemspec Rakefile ./src/
COPY lib/jsonapi/resources/version.rb ./src/lib/jsonapi/resources/
# This will run bundle install for each ruby version and leave the global version set as the last one.
# So we can control the default ruby version with the order in the ruby_versions.txt file, with last being the default
RUN xargs -I % sh -c 'cd src; rbenv global %; bundle install' < /ruby_versions.txt

# Scripts
COPY .docker/scripts/* /
RUN chmod +x /test_*

# COPY in the rest of the project
COPY lib/ ./src/lib
COPY locales/ ./src/locales
COPY test/ ./src/test
RUN ls -la

CMD ["/test_all"]
