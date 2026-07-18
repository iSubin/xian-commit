function evaluatePreToolUse(input, options = {}) {
  const toolName = String(input.tool_name || input.tool || '');
  const toolInput = input.tool_input || input;

  if (/^(Bash|Shell|shell)$/i.test(toolName)) {
    const command = commandFrom(toolInput);
    const blocked = firstBlockedCommand(command);
    if (blocked) {
      return {
        action: 'block',
        reason: `xian Harness pre-tool guard blocked a destructive or cross-session risky command: ${blocked.reason}`,
        command
      };
    }
    const warning = firstWarningCommand(command);
    if (warning) {
      return {
        action: 'warn',
        message: warning.message,
        command
      };
    }
  }

  if (/^(Write|Edit|MultiEdit|apply_patch)$/i.test(toolName)) {
    const payload = writeTargetText(toolName, toolInput);
    const hits = sensitiveFileHits(payload);
    if (hits.length > 0) {
      return {
        action: 'warn',
        message: `敏感文件写入：${hits.join(', ')}。请确保不要把密钥、Token 或生产配置提交到 Git。`
      };
    }
  }

  return { action: 'allow' };
}

function formatPreToolUseOutput(decision, runtime) {
  if (decision.action === 'allow') {
    return '{}';
  }

  if (decision.action === 'warn') {
    return JSON.stringify({ systemMessage: decision.message });
  }

  if (runtime === 'codex') {
    return JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: decision.reason
      }
    });
  }

  return JSON.stringify({
    decision: 'block',
    reason: decision.reason
  });
}

function commandFrom(inputValue) {
  if (typeof inputValue.command === 'string') {
    return inputValue.command;
  }
  if (typeof inputValue.cmd === 'string') {
    return inputValue.cmd;
  }
  if (Array.isArray(inputValue.argv)) {
    return inputValue.argv.join(' ');
  }
  return '';
}

function firstBlockedCommand(command) {
  if (!command) {
    return null;
  }

  const blocked = [
    { pattern: /[12]?\s*>\s*nul\b/i, reason: 'Windows nul redirection can create a real file named nul; use /dev/null or remove the redirect.' },
    { pattern: /git\s+reset\s+--hard/, reason: 'git reset --hard may discard user or cross-session changes.' },
    { pattern: /git\s+clean\s+-fd/, reason: 'git clean -fd may delete untracked user files.' },
    { pattern: /git\s+stash(\s|$)/, reason: 'git stash may hide user or cross-session changes.' },
    { pattern: /git\s+checkout\s+--\s+/, reason: 'git checkout -- may revert files outside the active task.' },
    { pattern: /git\s+push\s+--force\s+(origin\s+)?(main|master)/i, reason: 'git push --force to main or master may overwrite shared history.' },
    { pattern: /rm\s+-rf\s+\/(?!\w)/, reason: 'rm -rf / is destructive.' },
    { pattern: /rm\s+-rf\s+(--\s+)?(\.\/)?\*/, reason: 'rm -rf wildcard deletion is destructive.' },
    { pattern: /rm\s+-rf\s+(?:--\s+)?(?:["']\.\/?["']|\.\/?)(?=\s|$|[;&|])/, reason: 'rm -rf . may delete the current project.' },
    { pattern: /rm\s+-rf\s+["']?[A-Za-z]:[\/\\][^"'\s]*["']?\s*\*?/i, reason: 'rm -rf against a Windows absolute path is destructive.' },
    { pattern: /rm\s+-rf\s+(?:--\s+)?["']?\/(home|usr|etc|var|opt|root|tmp|private\/tmp|bin|sbin|lib)\b/i, reason: 'rm -rf against a system directory is destructive.' },
    { pattern: /drop\s+database/i, reason: 'database deletion is destructive.' },
    { pattern: /truncate\s+table/i, reason: 'table truncation is destructive.' },
    { pattern: />\s*\/dev\/sd[a-z]/, reason: 'direct writes to disk devices are destructive.' },
    { pattern: /mkfs\./, reason: 'filesystem formatting is destructive.' },
    { pattern: /:\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:/, reason: 'fork bomb commands can exhaust system resources.' },
    { pattern: /kill\s+-9/, reason: 'kill -9 may terminate unrelated developer processes.' },
    { pattern: /npx\s+kill-port/, reason: 'npx kill-port should be run explicitly by the user when needed.' },
    { pattern: /taskkill\s+(\/F\s+)?\/IM\s+node\.exe/i, reason: 'taskkill /IM node.exe may terminate the agent runtime.' },
    { pattern: /Stop-Process\b[^|;\n]*-Name\s+["']?node\*?["']?(\b|\s)/i, reason: 'Stop-Process -Name node may terminate the agent runtime.' },
    { pattern: /Get-Process\b[^|;\n]*\bnode\b[^|;\n]*\|\s*Stop-Process/i, reason: 'piped Stop-Process for node may terminate the agent runtime.' },
    { pattern: /\b(powershell|pwsh)(\.exe)?\s+[-\/]+(enc|encodedcommand|e\b)/i, reason: 'PowerShell EncodedCommand hides command content from static review.' },
    { pattern: /\bFormat-Volume\b/i, reason: 'PowerShell Format-Volume is destructive.' },
    { pattern: /\bClear-Disk\b[^|;\n]*-RemoveData/i, reason: 'PowerShell Clear-Disk removes disk data.' },
    { pattern: /\b(Remove-Partition|Remove-Volume)\b[^|;\n]*-(Confirm|Force)/i, reason: 'PowerShell partition or volume removal is destructive.' },
    { pattern: /\b(Stop-Computer|Restart-Computer)\b[^|;\n]*-Force/i, reason: 'forced computer stop or restart is unsafe for agent sessions.' },
    { pattern: /\bshutdown\b[^|;\n]*\/[rspf]\b/i, reason: 'shutdown can stop or restart the machine.' },
    { pattern: /\b(Invoke-RestMethod|Invoke-WebRequest|irm|iwr)\b[^|;\n]*\|\s*(iex|Invoke-Expression)\b/i, reason: 'remote download piped to execution cannot be statically audited.' }
  ];

  const direct = blocked.find((item) => item.pattern.test(command));
  if (direct) {
    return direct;
  }

  if (!/[A-Za-z]:[\\/][^"'\s|;<>]+/.test(command)) {
    return null;
  }

  const windowsDeletes = [
    { pattern: /Remove-Item\b/i, reason: 'PowerShell Remove-Item deletes a Windows absolute path.' },
    { pattern: /\b(rm|ri|erase|del)\b\s+[^|;\n]*[A-Za-z]:[\\/]/i, reason: 'Shell alias deletes a Windows absolute path.' },
    { pattern: /\b(rd|rmdir)\b[^|;\n]*\/[sS]\b/i, reason: 'cmd recursively deletes a Windows absolute path.' },
    { pattern: /\bdel\b[^|;\n]*\/[sSfF]\b/i, reason: 'cmd force deletes a Windows absolute path.' },
    { pattern: /\[\s*(System\.)?IO\.File\s*\]\s*::\s*Delete/i, reason: '.NET File API deletes a Windows absolute path.' },
    { pattern: /\[\s*(System\.)?IO\.Directory\s*\]\s*::\s*Delete/i, reason: '.NET Directory API deletes a Windows absolute path.' },
    { pattern: /\bNew-Object\s+(System\.)?IO\.(FileInfo|DirectoryInfo)\b/i, reason: '.NET FileInfo or DirectoryInfo can delete a Windows absolute path.' },
    { pattern: /Microsoft\.VisualBasic\.FileIO\.FileSystem.*Delete(File|Directory)/i, reason: 'VisualBasic FileSystem deletes a Windows absolute path.' },
    { pattern: /\b(Invoke-Expression|iex)\b/i, reason: 'Indirect execution with a Windows absolute path cannot be statically audited.' },
    { pattern: /\brobocopy\b[^|;\n]*\/(mir|purge)\b/i, reason: 'robocopy MIR or PURGE can delete a Windows absolute path.' },
    { pattern: /\bClear-Content\b/i, reason: 'PowerShell Clear-Content empties a Windows absolute path file.' }
  ];
  return windowsDeletes.find((item) => item.pattern.test(command)) ?? null;
}

function firstWarningCommand(command) {
  const warnings = [
    { pattern: /git\s+push\s+--force/, message: 'Force push 可能覆盖他人代码' },
    { pattern: /npm\s+publish/, message: '即将发布到 npm' },
    { pattern: /docker\s+system\s+prune/, message: '将清理所有未使用的 Docker 资源' }
  ];
  return warnings.find((item) => item.pattern.test(command)) ?? null;
}

function writeTargetText(name, inputValue) {
  if (/^apply_patch$/i.test(name)) {
    return extractPatchTargetPaths(inputValue.input || inputValue.patch || '').join('\n');
  }
  return [
    inputValue.file_path,
    inputValue.path
  ].filter(Boolean).join('\n');
}

function extractPatchTargetPaths(patchText) {
  if (typeof patchText !== 'string' || patchText.length === 0) {
    return [];
  }
  return patchText
    .split(/\r?\n/)
    .map((line) => line.match(/^\*\*\* (?:Add|Update|Delete) File: (.+)$/))
    .filter(Boolean)
    .map((match) => match[1].trim());
}

function sensitiveFileHits(payload) {
  const sensitive = [
    '.env.production',
    'application-prod.yml',
    'application-prod.yaml',
    'credentials.json',
    'secrets.json',
    '.gitee_token'
  ];
  return sensitive.filter((item) => payload.includes(item));
}

module.exports = {
  evaluatePreToolUse,
  formatPreToolUseOutput,
  commandFrom,
  firstBlockedCommand,
  sensitiveFileHits
};
