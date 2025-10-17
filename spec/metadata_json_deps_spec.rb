require 'spec_helper'
require 'json'
require 'tempfile'

describe MetadataJsonDeps do
  context 'no filenames' do
    subject { described_class.run([]) }

    it { expect { subject }.to_not output.to_stdout }
    it { expect { subject }.to_not output.to_stderr }
  end

  context 'with a module' do
    subject do
      Tempfile.create(['puppet-module', '.json']) do |f|
        mod = {
          "name": "puppet-dummy",
          "author": "Nobody",
          "license": "none",
          "source": "/dev/null",
          "summary": "Dummy",
          "version": "0.0.1",
          "dependencies": [
            {
              "name": module_name,
              "version_requirement": module_version,
            },
          ],
        }
        f.write(mod.to_json)
        f.flush

        described_class.run([f.path])
      end
    end

    let(:module_version) { '>= 0' }

    context 'that depends on a deprecated module' do
      context 'with replacement' do
        let(:module_name) { 'puppetlabs/mssql' }

        it { expect { subject }.to output(%r{\AChecking .+puppet-module.+\.json\n  puppetlabs/mssql was superseded by puppetlabs-sqlserver\Z}).to_stdout }
        it { expect { subject }.to_not output.to_stderr }
      end

      context 'without replacement' do
        context 'with reason' do
          let(:module_name) { 'puppetlabs/dsc' }

          it { expect { subject }.to output(%r{\AChecking .+puppet-module.+\.json\n  puppetlabs/dsc was deprecated: Migrate to https://forge\.puppet\.com/dsc modules\Z}).to_stdout }
          it { expect { subject }.to_not output.to_stderr }
        end

        # TODO find a module without a reason
        #context 'without reason' do
        #end
      end
    end

    context 'with current dependencies' do
      let(:module_name) { 'puppetlabs/stdlib' }

      it { expect { subject }.to output(%r{\AChecking .+puppet-module.+json\Z}).to_stdout }
      it { expect { subject }.to_not output.to_stderr }
    end

    context 'with an outdated dependency' do
      let(:module_name) { 'theforeman/motd' }
      let(:module_version) { '< 0.1.0' }

      it { expect { subject }.to output(%r{\AChecking .+puppet-module.+json\n  theforeman/motd \(< 0\.1\.0\) doesn't match \d+\.\d+\.\d+\Z}).to_stdout }
      it { expect { subject }.to_not output.to_stderr }
    end
  end

  describe '.bump_dependency' do
    subject do
      Tempfile.create(['puppet-module', '.json']) do |f|
        mod = {
          "name": "puppet-dummy",
          "author": "Nobody",
          "license": "none",
          "source": "/dev/null",
          "summary": "Dummy",
          "version": "0.0.1",
          "dependencies": [
            {
              "name": "puppetlabs-stdlib",
              "version_requirement": ">= 4.25.1 < 8.0.0",
            },
            {
              "name": "puppet/extlib",
              "version_requirement": ">= 2.0.0 < 6.0.0",
            },
          ],
        }
        f.write(mod.to_json)
        f.flush

        described_class.bump_dependency(f.path, module_name, upper_bound)
      end
    end

    context 'with a module using a dash' do
      let(:module_name) { 'puppetlabs-stdlib' }

      context 'passing a matching version' do
        let(:upper_bound) { '8.0.0' }

        it { is_expected.to eq(['>= 4.25.1 < 8.0.0', '>= 4.25.1 < 8.0.0']) }
      end

      context 'passing a new upper bound' do
        let(:upper_bound) { '9.0.0' }

        it { is_expected.to eq(['>= 4.25.1 < 8.0.0', '>= 4.25.1 < 9.0.0']) }
      end
    end

    context 'with a module using a slash' do
      let(:module_name) { 'puppet/extlib' }

      context 'passing a matching version' do
        let(:upper_bound) { '6.0.0' }

        it { is_expected.to eq(['>= 2.0.0 < 6.0.0', '>= 2.0.0 < 6.0.0']) }
      end

      context 'passing a new upper bound' do
        let(:upper_bound) { '7.0.0' }

        it { is_expected.to eq(['>= 2.0.0 < 6.0.0', '>= 2.0.0 < 7.0.0']) }
      end
    end

    context 'with a module not in dependencies' do
      let(:module_name) { 'puppet/example' }
      let(:upper_bound) { '42' }

      it { expect { subject }.to raise_error('Dependency puppet/example not found') }
    end
  end
end
