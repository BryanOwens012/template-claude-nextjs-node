import { LangfuseSpanProcessor } from '@langfuse/otel';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getEnvironment } from '@/config/environment.js';

let sdk: NodeSDK | null = null;

export const initTelemetry = () => {
  const env = getEnvironment();
  const publicKey = env.LANGFUSE_PUBLIC_KEY;
  const secretKey = env.LANGFUSE_SECRET_KEY;

  if (!publicKey || !secretKey) {
    console.warn('⚠️  Langfuse OTel tracing disabled (keys not set)');
    return;
  }

  try {
    sdk = new NodeSDK({
      spanProcessors: [
        new LangfuseSpanProcessor({
          // Only export AI SDK and Langfuse SDK spans — filter out Express, HTTP, and other library noise
          shouldExportSpan: (span) => {
            const scope = span.otelSpan.instrumentationScope.name;
            return scope === 'ai' || scope.startsWith('ai.') || scope === 'langfuse-sdk';
          },
        }),
      ],
    });
    sdk.start();
    console.log('✅ Langfuse OTel tracing initialized');
  } catch (error) {
    console.warn(`⚠️  OTel init failed: ${error instanceof Error ? error.message : String(error)}`);
    sdk = null;
  }
};

export const shutdownTelemetry = async () => {
  if (!sdk) return;
  try {
    await sdk.shutdown();
  } catch (error) {
    console.warn(
      `⚠️  OTel shutdown error: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
};
