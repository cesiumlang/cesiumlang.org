#!/usr/bin/env node

/**
 * Cross-platform build script that mirrors workspace to build/ and builds Quartz
 */

import { spawn } from 'child_process'
import { promises as fs } from 'fs'
import path from 'path'
import chokidar from 'chokidar'
import ignore from 'ignore'

// Parse command line arguments
const args = process.argv.slice(2)
const serve = args.includes('--serve')
const watch = args.includes('--watch')
const noBuildDir = args.includes('--no-build-dir')
const verbose = args.includes('--verbose')

const BUILD_DIR = 'build'

// Create gitignore filter
async function createGitignoreFilter() {
  const ig = ignore()
    .add('build') // Always exclude build directory
    .add('src/quartz') // Always exclude src/quartz symlink
    .add('.git') // Always exclude .git directory
    .add('**/.git') // Always exclude .git directories in subdirectories/submodules
    .add('build.js') // Always exclude build script itself
  
  try {
    const gitignoreContent = await fs.readFile('.gitignore', 'utf8')
    ig.add(gitignoreContent)
  } catch (error) {
    console.warn('Could not read .gitignore, using default exclusions')
  }
  
  return ig
}

async function copyFile(src, dest) {
  try {
    await fs.mkdir(path.dirname(dest), { recursive: true })
    
    // Copy file with attributes preserved
    await fs.copyFile(src, dest)
    
    // Get source file stats and preserve timestamps and permissions
    const stats = await fs.stat(src)
    await fs.utimes(dest, stats.atime, stats.mtime)
    await fs.chmod(dest, stats.mode)
    
    if (verbose) {
      console.log(`Copied ${path.relative('.', src)}`)
    }
  } catch (error) {
    console.warn(`Warning: Could not copy ${src}: ${error.message}`)
  }
}

async function copyDirectory(src, dest, ignoreFilter = null) {
  try {
    await fs.mkdir(dest, { recursive: true })
    
    // Preserve directory timestamps and permissions
    const dirStats = await fs.stat(src)
    await fs.utimes(dest, dirStats.atime, dirStats.mtime)
    await fs.chmod(dest, dirStats.mode)
    
    const entries = await fs.readdir(src, { withFileTypes: true })
    
    for (const entry of entries) {
      const srcPath = path.join(src, entry.name)
      const relativePath = path.relative('.', srcPath).replace(/\\/g, '/')
      
      // Check if this item should be excluded
      if (ignoreFilter && ignoreFilter.ignores(relativePath)) {
        continue
      }
      
      const destPath = path.join(dest, entry.name)
      
      if (entry.isDirectory()) {
        await copyDirectory(srcPath, destPath, ignoreFilter)
      } else {
        await copyFile(srcPath, destPath)
      }
    }
  } catch (error) {
    console.warn(`Warning: Could not copy directory ${src}: ${error.message}`)
  }
}

async function mirrorWorkspace() {
  console.log('Mirroring workspace to build directory...')
  
  // Clean and create build directory
  try {
    await fs.rm(BUILD_DIR, { recursive: true, force: true })
  } catch {}
  await fs.mkdir(BUILD_DIR, { recursive: true })
  
  // Create symlink to .git so git operations in build/ see the main repo
  try {
    const gitSymlinkPath = path.join(BUILD_DIR, '.git')
    const gitTargetPath = path.resolve('.git')
    
    // Use different approaches for Windows vs Unix
    if (process.platform === 'win32') {
      // Windows: use junction
      await new Promise((resolve, reject) => {
        const child = spawn('cmd', ['/c', 'mklink', '/J', gitSymlinkPath, gitTargetPath], { shell: true })
        child.on('close', (code) => code === 0 ? resolve() : reject(new Error(`mklink failed with code ${code}`)))
        child.on('error', reject)
      })
    } else {
      // Unix: use symlink
      await fs.symlink('../.git', gitSymlinkPath)
    }
    console.log('Created git symlink for accurate file dates')
  } catch (error) {
    console.warn('Warning: Could not create git symlink:', error.message)
  }
  
  // Create gitignore filter for exclusions
  const ignoreFilter = await createGitignoreFilter()
  
  // Copy workspace contents to build, excluding gitignored items
  await copyDirectory('.', BUILD_DIR, ignoreFilter)
  console.log('Workspace mirrored to build/')
}

async function copyCustomizations() {
  const targetMsg = noBuildDir ? 'quartz_repo' : 'build/quartz_repo'
  console.log(`Copying customizations from src/ to ${targetMsg}...`)
  
  const srcDir = noBuildDir ? 'src' : path.join(BUILD_DIR, 'src')
  const quartzRepoDir = noBuildDir ? 'quartz_repo' : path.join(BUILD_DIR, 'quartz_repo')
  
  try {
    const srcEntries = await fs.readdir(srcDir, { withFileTypes: true })
    
    for (const entry of srcEntries) {
      const srcPath = path.join(srcDir, entry.name)
      
      // Skip quartz symlink and quartz_overrides
      if (entry.name === 'quartz' || entry.name === 'quartz_overrides') {
        continue
      }
      
      if (entry.isDirectory()) {
        const destPath = path.join(quartzRepoDir, entry.name)
        await copyDirectory(srcPath, destPath)
      } else {
        const destPath = path.join(quartzRepoDir, entry.name)
        await copyFile(srcPath, destPath)
      }
    }
    
    // Handle quartz_overrides specially - copy contents into quartz_repo/quartz/
    try {
      await fs.access(path.join(srcDir, 'quartz_overrides'))
      const overridesEntries = await fs.readdir(path.join(srcDir, 'quartz_overrides'), { withFileTypes: true })
      
      for (const entry of overridesEntries) {
        const srcPath = path.join(srcDir, 'quartz_overrides', entry.name)
        const destPath = path.join(quartzRepoDir, 'quartz', entry.name)
        
        if (entry.isDirectory()) {
          await copyDirectory(srcPath, destPath)
        } else {
          await fs.mkdir(path.dirname(destPath), { recursive: true })
          await copyFile(srcPath, destPath)
        }
      }
      const overrideTarget = noBuildDir ? 'quartz_repo/quartz/' : 'build/quartz_repo/quartz/'
      console.log(`Copied quartz_overrides/ to ${overrideTarget}`)
    } catch (error) {
      // quartz_overrides doesn't exist, skip
    }
    
  } catch (error) {
    console.error('Error copying customizations:', error.message)
    throw error
  }
}

async function installDependencies(cwd) {
  console.log(`Installing dependencies in ${cwd}...`)
  
  return new Promise((resolve, reject) => {
    const child = spawn('npm', ['install'], {
      stdio: 'inherit',
      cwd,
      shell: true // Use shell to ensure npm is found on Windows
    })
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(`npm install failed with code ${code}`))
      }
    })
    
    child.on('error', reject)
  })
}

async function runQuartzBuild() {
  console.log('\nRunning Quartz build...')
  
  // Run npm command in appropriate directory
  const cwd = noBuildDir ? 'quartz_repo' : path.join(BUILD_DIR, 'quartz_repo')
  
  // Install dependencies first
  await installDependencies(cwd)
  
  // Determine node command based on flags - run quartz CLI directly
  // Point to content directory relative to quartz_repo
  const contentDir = noBuildDir ? '../content' : '../content'
  
  let nodeCommand
  if (serve && watch) {
    nodeCommand = ['quartz/bootstrap-cli.mjs', 'build', '--serve', '-d', contentDir]
  } else if (serve) {
    nodeCommand = ['quartz/bootstrap-cli.mjs', 'build', '--serve', '-d', contentDir]
  } else if (watch) {
    nodeCommand = ['quartz/bootstrap-cli.mjs', 'build', '-d', contentDir]
  } else {
    nodeCommand = ['quartz/bootstrap-cli.mjs', 'build', '-d', contentDir]
  }
  
  return new Promise((resolve, reject) => {
    const child = spawn('node', nodeCommand, {
      stdio: 'inherit',
      cwd,
      shell: true
    })
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(`Quartz build failed with code ${code}`))
      }
    })
    
    child.on('error', reject)
  })
}

async function setupWatcher() {
  console.log('Setting up file watcher for workspace changes...')
  
  // Create gitignore filter for the watcher
  const ignoreFilter = await createGitignoreFilter()
  
  const watcher = chokidar.watch('.', {
    ignored: (path, stats) => {
      const relativePath = path.replace(/\\/g, '/')
      // Skip empty paths and current directory
      if (!relativePath || relativePath === '.' || relativePath === './') {
        return false
      }
      // Remove leading ./ if present
      const cleanPath = relativePath.startsWith('./') ? relativePath.slice(2) : relativePath
      return ignoreFilter.ignores(cleanPath)
    },
    persistent: true
  })
  
  let debounceTimer
  let isReady = false
  
  // Wait for initial scan to complete
  watcher.on('ready', () => {
    isReady = true
    console.log('File watcher ready - monitoring for changes...')
  })
  
  watcher.on('all', (event, filePath) => {
    // Only log events after initial scan unless verbose mode is enabled
    if (verbose || (isReady && (event === 'change' || event === 'add' || event === 'unlink'))) {
      console.log(`${event}: ${filePath}`)
    }
    
    // Only process changes after initial scan
    if (!isReady) return
    
    // Debounce file changes
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(async () => {
      try {
        console.log('Syncing workspace changes to build directory...')
        
        // For file changes, just copy the specific file
        if (event === 'change' || event === 'add') {
          const buildPath = path.join(BUILD_DIR, filePath)
          await copyFile(filePath, buildPath)
          
          // If it's a src file, also copy customizations to quartz_repo
          if (filePath.startsWith('src/')) {
            console.log('Source file changed, updating customizations in quartz_repo...')
            await copyCustomizations()
          }
        } else if (event === 'unlink') {
          // Remove file from build directory
          const buildPath = path.join(BUILD_DIR, filePath)
          try {
            await fs.unlink(buildPath)
            console.log(`Removed ${buildPath}`)
          } catch {}
          
          // If it's a src file, also update customizations
          if (filePath.startsWith('src/')) {
            console.log('Source file removed, updating customizations in quartz_repo...')
            await copyCustomizations()
          }
        }
      } catch (error) {
        console.error('Error syncing changes:', error.message)
      }
    }, 500) // 500ms debounce
  })
  
  return watcher
}

async function main() {
  try {
    if (!noBuildDir) {
      await mirrorWorkspace()
    }
    
    await copyCustomizations()
    
    if ((watch || serve) && !noBuildDir) {
      // Setup file watcher for workspace changes (only when using build dir)
      const watcher = await setupWatcher()
      
      // Setup cleanup on exit
      process.on('SIGINT', () => {
        console.log('\nShutting down...')
        watcher.close()
        process.exit(0)
      })
    }
    
    await runQuartzBuild()
    
    if (!watch && !serve) {
      console.log('\nBuild completed!')
    }
  } catch (error) {
    console.error('Build failed:', error.message)
    process.exit(1)
  }
}

main()