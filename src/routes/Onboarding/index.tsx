import { useState } from 'react';
import Welcome from './Welcome';
import Identity from './Identity';
import ServerPicker, { PickedServer } from './ServerPicker';
import Connect from './Connect';
import FirstProject from './FirstProject';
import Done from './Done';

export type OnboardingStep =
  | 'welcome'
  | 'identity'
  | 'server'
  | 'connect'
  | 'project'
  | 'done';

export default function OnboardingFlow() {
  const [step, setStep] = useState<OnboardingStep>('welcome');
  const [server, setServer] = useState<PickedServer | null>(null);
  const [serverId, setServerId] = useState<string | null>(null);

  return (
    <div className="h-full w-full flex items-center justify-center bg-[var(--color-bg)]">
      <div className="w-full max-w-[360px] px-6">
        <div key={step} className="animate-fade-in">
          {step === 'welcome' && <Welcome onNext={() => setStep('identity')} />}
          {step === 'identity' && <Identity onNext={() => setStep('server')} />}
          {step === 'server' && (
            <ServerPicker
              onNext={(s) => {
                setServer(s);
                setStep('connect');
              }}
            />
          )}
          {step === 'connect' && server && (
            <Connect
              server={server}
              onDone={(id) => {
                setServerId(id);
                setStep('project');
              }}
              onBack={() => setStep('server')}
            />
          )}
          {step === 'project' && (
            <FirstProject
              gitServerId={serverId}
              onDone={() => setStep('done')}
            />
          )}
          {step === 'done' && <Done />}
        </div>
      </div>
      <style>{`
        @keyframes fade-in {
          from { opacity: 0; transform: translateX(16px); }
          to { opacity: 1; transform: translateX(0); }
        }
        .animate-fade-in { animation: fade-in 350ms ease-in-out; }
      `}</style>
    </div>
  );
}
